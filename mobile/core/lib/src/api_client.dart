import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// Cliente HTTP mínimo para a API. Converte erros (ProblemDetail) em [ApiException].
class ApiClient {
  ApiClient({String? baseUrl, this.token, this.onUnauthorized, http.Client? httpClient})
      : baseUrl = baseUrl ?? AppConfig.apiUrl,
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Retorna o token JWT atual (app do salão). Nulo = requisição anônima.
  final String? Function()? token;

  /// Chamado quando a API responde 401 com token (sessão expirada).
  final void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 20);

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body ?? const {});

  Future<dynamic> put(String path, Object body) => _send('PUT', path, body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    final jwt = token?.call();
    if (jwt != null) request.headers['Authorization'] = 'Bearer $jwt';
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on TimeoutException {
      throw ApiException(0, 'O servidor demorou para responder. Tente novamente.');
    } on SocketException {
      throw ApiException(0, 'Sem conexão com a internet.');
    } on http.ClientException {
      throw ApiException(0, 'Não foi possível conectar ao servidor.');
    }

    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return text.isEmpty ? null : jsonDecode(text);
    }
    if (res.statusCode == 401 && jwt != null) onUnauthorized?.call();
    throw ApiException(res.statusCode, _message(text, res.statusCode));
  }

  static String _message(String body, int status) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['detail'] is String) return json['detail'] as String;
    } catch (_) {}
    return switch (status) {
      401 => 'Sessão expirada. Entre novamente.',
      403 => 'Você não tem permissão para isso.',
      404 => 'Não encontrado.',
      _ => 'Erro inesperado ($status).',
    };
  }
}
