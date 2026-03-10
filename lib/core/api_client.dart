import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_config.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 180),
      receiveTimeout: const Duration(seconds: 180),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!options.path.contains('/auth/')) {
          final token = await _storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (DioException e, handler) {
        handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<String?> readToken() => _storage.read(key: _tokenKey);
}

// Singleton
final apiClient = ApiClient();
