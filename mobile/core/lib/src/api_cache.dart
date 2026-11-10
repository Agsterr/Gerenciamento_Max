import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Resposta guardada de um GET.
class CachedResponse {
  CachedResponse(this.data, this.at);

  final dynamic data;
  final DateTime at;
}

/// Alteração feita sem internet, esperando para ir ao servidor.
class QueuedRequest {
  QueuedRequest({required this.method, required this.path, this.body, required this.at});

  factory QueuedRequest.fromJson(Map<String, dynamic> j) =>
      QueuedRequest(method: j['method'] as String, path: j['path'] as String, body: j['body'], at: DateTime.parse(j['at'] as String));

  final String method;
  final String path;
  final Object? body;
  final DateTime at;

  Map<String, dynamic> toJson() => {'method': method, 'path': path, 'body': body, 'at': at.toIso8601String()};
}

/// Dados do servidor guardados no celular, separados por usuário ([scope]): as telas abrem na hora e funcionam sem
/// internet; o que for alterado sem internet fica numa fila ([outbox]) até conectar. Em arquivos (não em
/// SharedPreferences), porque a agenda e as listas podem ser grandes. Sem disco (testes), fica só na memória.
class ApiCache {
  ApiCache({
    required this.scope,
    this.freshFor = const Duration(seconds: 15),
    this.fallbackAfter = const Duration(milliseconds: 900),
    Future<Directory> Function()? baseDir,
  }) : _baseDir = baseDir ?? getApplicationSupportDirectory;

  /// Usuário logado (ex.: o id do token). Nulo = não guarda nada.
  final String? Function() scope;

  /// Resposta mais nova que isso é usada sem ir ao servidor (evita buscar de novo a cada troca de tela).
  final Duration freshFor;

  /// Com resposta guardada, espera o servidor no máximo isso; depois mostra a guardada e atualiza quando chegar.
  final Duration fallbackAfter;

  final Future<Directory> Function() _baseDir;
  final Map<String, CachedResponse> _memory = {};
  final Map<String, List<QueuedRequest>> _outbox = {};
  Directory? _root;
  bool _noDisk = false;

  Future<Directory?> _dir(String scope) async {
    if (_noDisk) return null;
    try {
      _root ??= await _baseDir();
      final dir = Directory('${_root!.path}/api_cache/$scope');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    } catch (_) {
      _noDisk = true; // sem disco (ex.: testes): só memória
      return null;
    }
  }

  static String _file(String path) => sha1.convert(utf8.encode(path)).toString();

  Future<CachedResponse?> read(String path) async {
    final s = scope();
    if (s == null) return null;
    final key = '$s|$path';
    final mem = _memory[key];
    if (mem != null) return mem;
    final dir = await _dir(s);
    if (dir == null) return null;
    try {
      final f = File('${dir.path}/${_file(path)}.json');
      if (!f.existsSync()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return _memory[key] = CachedResponse(j['data'], DateTime.parse(j['at'] as String));
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String path, dynamic data) async {
    final s = scope();
    if (s == null) return;
    final now = DateTime.now();
    _memory['$s|$path'] = CachedResponse(data, now);
    final dir = await _dir(s);
    if (dir == null) return;
    try {
      await File('${dir.path}/${_file(path)}.json').writeAsString(jsonEncode({'data': data, 'at': now.toIso8601String()}));
    } catch (_) {}
  }

  /// Altera as respostas guardadas cujo caminho começa com [prefix] (ex.: aplicar na agenda guardada uma ação feita
  /// sem internet). [patch] recebe os dados e devolve os novos.
  Future<void> patchAll(String prefix, dynamic Function(dynamic data) patch) async {
    final s = scope();
    if (s == null) return;
    final head = '$s|$prefix';
    for (final key in _memory.keys.where((k) => k.startsWith(head)).toList()) {
      final old = _memory[key]!;
      final path = key.substring(s.length + 1);
      _memory[key] = CachedResponse(patch(old.data), old.at);
      final dir = await _dir(s);
      if (dir == null) continue;
      try {
        await File('${dir.path}/${_file(path)}.json')
            .writeAsString(jsonEncode({'data': _memory[key]!.data, 'at': old.at.toIso8601String()}));
      } catch (_) {}
    }
  }

  /// Marca como velhas as respostas guardadas: a próxima leitura vai ao servidor (depois de enviar alterações).
  void markStale() {
    _memory.updateAll((_, v) => CachedResponse(v.data, DateTime.fromMillisecondsSinceEpoch(0)));
  }

  // ---- fila de alterações feitas sem internet ----

  Future<List<QueuedRequest>> outbox() async {
    final s = scope();
    if (s == null) return [];
    final mem = _outbox[s];
    if (mem != null) return mem;
    final dir = await _dir(s);
    var list = <QueuedRequest>[];
    if (dir != null) {
      try {
        final f = File('${dir.path}/outbox.json');
        if (f.existsSync()) {
          list = [for (final j in jsonDecode(await f.readAsString()) as List) QueuedRequest.fromJson(j as Map<String, dynamic>)];
        }
      } catch (_) {}
    }
    return _outbox[s] = list;
  }

  Future<void> saveOutbox(List<QueuedRequest> list) async {
    final s = scope();
    if (s == null) return;
    _outbox[s] = list;
    final dir = await _dir(s);
    if (dir == null) return;
    try {
      await File('${dir.path}/outbox.json').writeAsString(jsonEncode([for (final q in list) q.toJson()]));
    } catch (_) {}
  }

  /// Ao sair da conta: apaga o que estava guardado desse usuário.
  Future<void> clear() async {
    final s = scope();
    if (s == null) return;
    _memory.removeWhere((k, _) => k.startsWith('$s|'));
    _outbox.remove(s);
    final dir = await _dir(s);
    try {
      if (dir != null && dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}
