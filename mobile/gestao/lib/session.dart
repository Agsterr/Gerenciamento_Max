import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:salao_core/salao_core.dart';

enum SessionState { restoring, offline, signedOut, signedIn, blocked }

/// Login do usuário do salão. O JWT fica no Keychain (iOS) / Keystore (Android).
class Session extends ChangeNotifier {
  Session({http.Client? httpClient}) : _httpClient = httpClient;

  static const _tokenKey = 'jwt';
  static const _emailKey = 'last_email';
  // "Manter conectado": com ele marcado a senha fica no Keystore/Keychain e o app entra de novo quando o token de 24h vence.
  static const _passwordKey = 'saved_password';
  final _storage = const FlutterSecureStorage();
  final http.Client? _httpClient;

  String? _token;
  User? _user;
  SessionState state = SessionState.restoring;

  /// Motivo do bloqueio (super-admin), quando [state] é [SessionState.blocked].
  String? blockedReason;

  late final ApiClient api =
      ApiClient(
      token: () => _token,
      onUnauthorized: signOut,
      onAccountBlocked: _blocked,
      reauthenticate: _reauthenticate,
      httpClient: _httpClient);

  Future<bool>? _relogin;

  User get user => _user!;

  /// Último e-mail usado, para já vir preenchido na tela de login.
  String? lastEmail;

  Future<void> restore() async {
    state = SessionState.restoring;
    notifyListeners();
    _token = await _storage.read(key: _tokenKey);
    lastEmail = await _storage.read(key: _emailKey);
    if (_token == null) {
      state = SessionState.signedOut;
    } else {
      try {
        _user = User.fromJson(await api.get('/api/me') as Map<String, dynamic>);
        state = SessionState.signedIn;
      } on AccountBlockedException {
        return; // _blocked já trocou o estado e limpou a sessão.
      } on ApiException catch (e) {
        state = e.status == 0 ? SessionState.offline : SessionState.signedOut;
        if (state == SessionState.signedOut) await _storage.delete(key: _tokenKey);
      }
    }
    notifyListeners();
  }

  /// Token de 24h vencido: entra de novo com a senha salva (só existe se marcou "Manter conectado").
  /// Várias requisições ao mesmo tempo compartilham um único login.
  Future<bool> _reauthenticate() => _relogin ??= _doRelogin().whenComplete(() => _relogin = null);

  Future<bool> _doRelogin() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || password == null) return false;
    // Sem o token vencido: um Bearer inválido derruba até o endpoint de login.
    final anonymous = ApiClient(onAccountBlocked: _blocked, httpClient: _httpClient);
    try {
      final json = await anonymous.post('/api/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
      _token = json['token'] as String;
      await _storage.write(key: _tokenKey, value: _token);
      return true;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 400) await _storage.delete(key: _passwordKey); // senha mudou
      if (e.status == 0) rethrow; // sem rede: não desloga
      return false;
    }
  }

  Future<void> login(String email, String password, {bool keepSignedIn = false}) async {
    await _authenticate(api.post('/api/auth/login', {'email': email, 'password': password}));
    lastEmail = email;
    await _storage.write(key: _emailKey, value: email);
    if (keepSignedIn) {
      await _storage.write(key: _passwordKey, value: password);
    } else {
      await _storage.delete(key: _passwordKey);
    }
  }

  Future<void> register(Map<String, String> data) => _authenticate(api.post('/api/auth/register', data));

  Future<void> _authenticate(Future<dynamic> request) async {
    final json = await request as Map<String, dynamic>;
    _token = json['token'] as String;
    _user = User.fromJson(json['user'] as Map<String, dynamic>);
    await _storage.write(key: _tokenKey, value: _token);
    state = SessionState.signedIn;
    notifyListeners();
  }

  Future<void> signOut() async {
    _token = null;
    _user = null;
    blockedReason = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _passwordKey);
    state = SessionState.signedOut;
    notifyListeners();
  }

  /// API respondeu 403 ACCOUNT_BLOCKED (qualquer requisição, inclusive o login): derruba a sessão
  /// e mostra a tela de bloqueio até o usuário tocar em "Sair".
  void _blocked(String reason) {
    _token = null;
    _user = null;
    blockedReason = reason;
    state = SessionState.blocked;
    notifyListeners();
    _storage.delete(key: _tokenKey).catchError((Object _) {});
    _storage.delete(key: _passwordKey).catchError((Object _) {});
  }

  /// Exclusão de conta (App Store 5.1.1(v) / Google Play). Retorna true se o salão foi apagado.
  Future<bool> deleteAccount(String password) async {
    final json = await api.post('/api/me/delete', {'password': password}) as Map<String, dynamic>;
    await signOut();
    return json['salonDeleted'] as bool;
  }
}
