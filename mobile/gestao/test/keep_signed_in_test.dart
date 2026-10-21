import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salao_gestao/session.dart';

const _user = {
  'id': 1,
  'name': 'Ana',
  'email': 'ana@x.com',
  'role': 'OWNER',
  'salonId': 1,
  'salonSlug': 'ana',
};

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

void main() {
  const storage = FlutterSecureStorage();
  late List<String> calls;

  /// Servidor de mentira: só aceita o token "novo"; o login devolve "novo".
  MockClient server({int loginStatus = 200}) => MockClient((req) async {
        calls.add('${req.method} ${req.url.path} ${req.headers['Authorization'] ?? '-'}');
        if (req.url.path == '/api/auth/login') {
          return loginStatus == 200 ? _json({'token': 'novo', 'user': _user}) : _json({'status': 401, 'detail': 'x'}, 401);
        }
        if (req.headers['Authorization'] == 'Bearer novo') return _json(_user);
        return _json({'status': 401, 'detail': 'expirado'}, 401);
      });

  setUp(() {
    calls = [];
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('com "Manter conectado", token vencido entra de novo sozinho', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt': 'velho', 'last_email': 'ana@x.com', 'saved_password': 'segredo'});
    final session = Session(httpClient: server());
    await session.restore();
    expect(session.state, SessionState.signedIn);
    expect(calls, [
      'GET /api/me Bearer velho',
      'POST /api/auth/login -', // sem o token vencido
      'GET /api/me Bearer novo',
    ]);
    expect(await storage.read(key: 'jwt'), 'novo');
  });

  test('sem "Manter conectado", token vencido volta para o login', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt': 'velho', 'last_email': 'ana@x.com'});
    final session = Session(httpClient: server());
    await session.restore();
    expect(session.state, SessionState.signedOut);
    expect(calls, ['GET /api/me Bearer velho']);
  });

  test('senha trocada: apaga a senha salva e volta para o login', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt': 'velho', 'last_email': 'ana@x.com', 'saved_password': 'antiga'});
    final session = Session(httpClient: server(loginStatus: 401));
    await session.restore();
    expect(session.state, SessionState.signedOut);
    expect(await storage.read(key: 'saved_password'), isNull);
  });

  test('login guarda a senha só se marcar, e sair apaga', () async {
    final session = Session(httpClient: server());
    await session.login('ana@x.com', 'segredo', keepSignedIn: true);
    expect(await storage.read(key: 'saved_password'), 'segredo');
    await session.signOut();
    expect(await storage.read(key: 'saved_password'), isNull);

    await session.login('ana@x.com', 'segredo');
    expect(await storage.read(key: 'saved_password'), isNull);
  });
}
