import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'user_email';
  static const _nameKey = 'user_name';

  Future<void> saveSession({
    required String token,
    required int userId,
    required String email,
    required String fullName,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId.toString());
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _nameKey, value: fullName);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null;
  }

  Future<int?> getUserId() async {
    final id = await _storage.read(key: _userIdKey);
    return id == null ? null : int.tryParse(id);
  }

  Future<String?> getUserName() => _storage.read(key: _nameKey);

  Future<String?> getUserEmail() => _storage.read(key: _emailKey);

  Future<void> clearSession() => _storage.deleteAll();
}

final authService = AuthService();
