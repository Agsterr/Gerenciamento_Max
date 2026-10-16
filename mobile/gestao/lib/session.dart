import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:salao_core/salao_core.dart';

enum SessionState { restoring, offline, signedOut, signedIn }

/// Login do usuário do salão. O JWT fica no Keychain (iOS) / Keystore (Android).
class Session extends ChangeNotifier {
  static const _tokenKey = 'jwt';
  final _storage = const FlutterSecureStorage();

  String? _token;
  User? _user;
  SessionState state = SessionState.restoring;

  late final ApiClient api = ApiClient(token: () => _token, onUnauthorized: signOut);

  User get user => _user!;

  Future<void> restore() async {
    state = SessionState.restoring;
    notifyListeners();
    _token = await _storage.read(key: _tokenKey);
    if (_token == null) {
      state = SessionState.signedOut;
    } else {
      try {
        _user = User.fromJson(await api.get('/api/me') as Map<String, dynamic>);
        state = SessionState.signedIn;
      } on ApiException catch (e) {
        state = e.status == 0 ? SessionState.offline : SessionState.signedOut;
        if (state == SessionState.signedOut) await _storage.delete(key: _tokenKey);
      }
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) =>
      _authenticate(api.post('/api/auth/login', {'email': email, 'password': password}));

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
    await _storage.delete(key: _tokenKey);
    state = SessionState.signedOut;
    notifyListeners();
  }

  /// Exclusão de conta (App Store 5.1.1(v) / Google Play). Retorna true se o salão foi apagado.
  Future<bool> deleteAccount(String password) async {
    final json = await api.post('/api/me/delete', {'password': password}) as Map<String, dynamic>;
    await signOut();
    return json['salonDeleted'] as bool;
  }
}
