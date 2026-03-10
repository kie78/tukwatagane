import 'package:dio/dio.dart';

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final Map<String, String>? fieldErrors;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fieldErrors,
  });

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return ApiException(
        statusCode: e.response?.statusCode ?? 0,
        code: data['code'] ?? 'UNKNOWN',
        message: data['message'] ?? e.message ?? 'Unknown error',
        fieldErrors: (data['fieldErrors'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())),
      );
    }
    return ApiException(
      statusCode: e.response?.statusCode ?? 0,
      code: 'NETWORK_ERROR',
      message: e.message ?? 'Network error',
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
