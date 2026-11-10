import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';

import 'api_cache.dart';
import 'config.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message, {this.code});

  final int status;
  final String message;

  /// Campo `code` do ProblemDetail, quando a API manda (ex.: `ACCOUNT_BLOCKED`).
  final String? code;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// Usuário ou salão bloqueado pelo super-admin: 403 com `"code": "ACCOUNT_BLOCKED"`.
/// [message] é o motivo (`detail` do ProblemDetail).
class AccountBlockedException extends ApiException {
  AccountBlockedException(String reason) : super(403, reason, code: codeValue);

  static const codeValue = 'ACCOUNT_BLOCKED';
  static const defaultReason = 'Sua conta foi bloqueada.';
}

/// Cliente HTTP mínimo para a API. Converte erros (ProblemDetail) em [ApiException].
/// Conexão e fila de envio do app.
@immutable
class ApiStatus {
  const ApiStatus({this.online = true, this.pending = 0, this.failures = const []});

  final bool online;

  /// Alterações feitas sem internet esperando para ir ao servidor.
  final int pending;

  /// Alterações que o servidor recusou ao sincronizar (mensagens para mostrar).
  final List<String> failures;
}

class ApiClient {
  ApiClient(
      {String? baseUrl,
      this.token,
      this.onUnauthorized,
      this.onAccountBlocked,
      this.reauthenticate,
      this.cache,
      http.Client? httpClient})
      : baseUrl = baseUrl ?? AppConfig.apiUrl,
        _http = httpClient ?? http.Client();

  /// Dados guardados no celular (app do salão): abre as telas na hora, funciona sem internet e guarda alterações
  /// feitas sem internet para enviar depois. Nulo = sem cache (comportamento antigo).
  final ApiCache? cache;

  /// Situação da conexão e da fila de envio, para a faixa "sem internet" das telas.
  final ValueNotifier<ApiStatus> status = ValueNotifier(const ApiStatus());

  /// Avisa quando dados de um caminho chegaram do servidor diferentes do que estava na tela ('*' = tudo mudou).
  Stream<String> get refreshed => _refreshed.stream;
  final StreamController<String> _refreshed = StreamController<String>.broadcast();

  /// Chamado quando uma alteração foi guardada para enviar depois (sem internet).
  void Function()? onQueued;

  /// Aplica nos dados guardados o efeito de uma alteração feita sem internet (ex.: horário confirmado), para a
  /// tela já mostrar o resultado antes de enviar.
  Future<void> Function(ApiCache cache, QueuedRequest request)? optimistic;

  Timer? _retry;
  bool _syncing = false;

  /// Chamado (antes de lançar [AccountBlockedException]) quando a API diz que a conta está bloqueada —
  /// em qualquer requisição, inclusive no login. Recebe o motivo.
  final void Function(String reason)? onAccountBlocked;

  final String baseUrl;
  final http.Client _http;

  /// Retorna o token JWT atual (app do salão). Nulo = requisição anônima.
  final String? Function()? token;

  /// Chamado quando a API responde 401 com token (sessão expirada).
  final void Function()? onUnauthorized;

  /// Chamado no 401 com token (token de 24h vencido): se o usuário marcou "Manter conectado", entra de novo
  /// com a senha salva e devolve true; a requisição é repetida uma vez com o token novo.
  final Future<bool> Function()? reauthenticate;

  static const _timeout = Duration(seconds: 20);

  Future<dynamic> get(String path) {
    final c = cache;
    if (c == null || c.scope() == null) return _send('GET', path);
    return _cachedGet(c, path);
  }

  /// [queue]: sem internet, guarda a alteração e envia quando conectar (devolve null). Só para ações que não
  /// precisam da resposta do servidor (ex.: confirmar um horário).
  Future<dynamic> post(String path, [Object? body, bool queue = false]) => _write('POST', path, body ?? const {}, queue);

  Future<dynamic> put(String path, Object body, {bool queue = false}) => _write('PUT', path, body, queue);

  Future<dynamic> delete(String path, {bool queue = false}) => _write('DELETE', path, null, queue);

  Future<dynamic> _cachedGet(ApiCache c, String path) async {
    final cached = await c.read(path);
    if (cached != null && DateTime.now().difference(cached.at) < c.freshFor) return cached.data;
    final network = _send('GET', path).then((data) async {
      await c.write(path, data);
      return data;
    });
    if (cached == null) return network;
    final done = Completer<dynamic>();
    network.then((data) {
      if (!done.isCompleted) {
        done.complete(data);
      } else if (jsonEncode(data) != jsonEncode(cached.data)) {
        _refreshed.add(path); // a tela mostrou o guardado: chegou coisa nova
      }
    }, onError: (Object e) {
      if (done.isCompleted) return;
      // sem internet: segue com o que está guardado
      if (e is ApiException && e.status == 0) {
        done.complete(cached.data);
      } else {
        done.completeError(e);
      }
    });
    Timer(c.fallbackAfter, () {
      if (!done.isCompleted) done.complete(cached.data);
    });
    return done.future;
  }

  Future<dynamic> _write(String method, String path, Object? body, bool queue) async {
    try {
      return await _send(method, path, body);
    } on ApiException catch (e) {
      final c = cache;
      if (!queue || e.status != 0 || c == null || c.scope() == null) rethrow;
      final request = QueuedRequest(method: method, path: path, body: body, at: DateTime.now());
      final list = [...await c.outbox(), request];
      await c.saveOutbox(list);
      try {
        await optimistic?.call(c, request);
      } catch (_) {}
      _update(pending: list.length);
      _scheduleRetry();
      onQueued?.call();
      return null;
    }
  }

  /// Envia o que ficou guardado sem internet, na ordem. Chamado sozinho quando a conexão volta; pode ser chamado
  /// ao abrir o app.
  Future<void> sync() async {
    final c = cache;
    if (c == null || c.scope() == null || _syncing) return;
    _syncing = true;
    try {
      var list = await c.outbox();
      if (list.isEmpty) {
        // fila vazia, mas estava sem internet: testa a conexão com algo leve
        if (!status.value.online) await _send('GET', '/api/me');
        return;
      }
      final failures = <String>[...status.value.failures];
      var sent = 0;
      while (list.isNotEmpty) {
        final q = list.first;
        try {
          await _send(q.method, q.path, q.body);
        } on ApiException catch (e) {
          if (e.status == 0) break; // ainda sem internet: tenta depois
          failures.add(e.message); // o servidor recusou (ex.: horário já cancelado): não adianta repetir
        } catch (e) {
          failures.add('Não foi possível enviar uma alteração.'); // resposta estranha: não trava a fila
        }
        list = list.sublist(1);
        await c.saveOutbox(list);
        sent++;
      }
      _update(pending: list.length, failures: failures);
      if (sent > 0) {
        c.markStale();
        _refreshed.add('*');
      }
    } catch (_) {
      // sem internet ainda
    } finally {
      _syncing = false;
      if (status.value.pending > 0 || !status.value.online) _scheduleRetry();
    }
  }

  /// Carrega a fila guardada (ao abrir o app) e tenta enviar.
  Future<void> resume() async {
    final c = cache;
    if (c == null || c.scope() == null) return;
    _update(pending: (await c.outbox()).length);
    await sync();
  }

  void clearFailures() => _update(failures: const []);

  void _scheduleRetry() {
    _retry ??= Timer.periodic(const Duration(seconds: 20), (t) {
      if (status.value.online && status.value.pending == 0) {
        t.cancel();
        _retry = null;
        return;
      }
      sync();
    });
  }

  void _update({bool? online, int? pending, List<String>? failures}) {
    final v = status.value;
    final next = ApiStatus(online: online ?? v.online, pending: pending ?? v.pending, failures: failures ?? v.failures);
    if (next.online != v.online || next.pending != v.pending || next.failures.length != v.failures.length) status.value = next;
  }

  void _connected(bool ok) {
    final was = status.value.online;
    _update(online: ok);
    if (!ok) {
      if (cache != null) _scheduleRetry();
    } else if (!was) {
      // voltou a internet: envia a fila e avisa as telas para atualizarem
      if (status.value.pending > 0) {
        Future.microtask(sync);
      } else {
        cache?.markStale();
        _refreshed.add('*');
      }
    }
  }

  /// Envio de arquivo (multipart/form-data), ex.: fotos do portfólio.
  Future<dynamic> upload(String path,
      {required List<int> bytes, required String filename, String field = 'file', Map<String, String> fields = const {}}) {
    return _execute(
      () => http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
        ..fields.addAll(fields)
        ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename)),
      timeout: const Duration(seconds: 90),
    );
  }

  Future<dynamic> _send(String method, String path, [Object? body]) {
    return _execute(() {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      return request;
    });
  }

  /// [build] cria a requisição de novo a cada tentativa (uma requisição HTTP não pode ser reenviada).
  Future<dynamic> _execute(http.BaseRequest Function() build, {Duration timeout = _timeout, bool retried = false}) async {
    final request = build();
    final jwt = token?.call();
    if (jwt != null) request.headers['Authorization'] = 'Bearer $jwt';
    request.headers['Accept'] = 'application/json';
    request.headers['X-App-Channel'] = AppConfig.apiChannel;

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } on TimeoutException {
      _connected(false);
      throw ApiException(0, 'O servidor demorou para responder. Tente novamente.');
    } on SocketException {
      _connected(false);
      throw ApiException(0, 'Sem conexão com a internet.');
    } on http.ClientException {
      _connected(false);
      throw ApiException(0, 'Não foi possível conectar ao servidor.');
    }
    _connected(true);

    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return text.isEmpty ? null : jsonDecode(text);
    }
    final problem = _problem(text);
    if (res.statusCode == 403 && problem?['code'] == AccountBlockedException.codeValue) {
      final detail = problem?['detail'];
      final reason = detail is String && detail.trim().isNotEmpty ? detail.trim() : AccountBlockedException.defaultReason;
      onAccountBlocked?.call(reason);
      throw AccountBlockedException(reason);
    }
    if (res.statusCode == 401 && jwt != null) {
      if (!retried && reauthenticate != null && await reauthenticate!()) {
        return _execute(build, timeout: timeout, retried: true);
      }
      onUnauthorized?.call();
    }
    final code = problem?['code'];
    throw ApiException(res.statusCode, _message(problem, res.statusCode), code: code is String ? code : null);
  }

  static Map<String, dynamic>? _problem(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) return json;
    } catch (_) {}
    return null;
  }

  static String _message(Map<String, dynamic>? problem, int status) {
    if (problem?['detail'] is String) return problem!['detail'] as String;
    return switch (status) {
      401 => 'Sessão expirada. Entre novamente.',
      403 => 'Você não tem permissão para isso.',
      404 => 'Não encontrado.',
      _ => 'Erro inesperado ($status).',
    };
  }
}

/// Confirma ao servidor que o aviso (push) chegou ao celular. Não precisa de login: vale com o código
/// do aviso e o do celular que o próprio servidor mandou. Falha em silêncio (o servidor só registra).
Future<void> ackPush(String? messageId, String? deviceToken, {ApiClient? api}) async {
  if (messageId == null || messageId.isEmpty || deviceToken == null || deviceToken.isEmpty) return;
  try {
    await (api ?? ApiClient()).post('/api/push/ack', {'id': messageId, 'token': deviceToken});
  } catch (_) {
    // sem rede agora: o aviso já foi entregue; a confirmação é só um registro
  }
}
