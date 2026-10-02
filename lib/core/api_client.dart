import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

/// Error de la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors = const {}});
  final String message;
  final int? statusCode;
  final Map<String, List<String>> errors;

  @override
  String toString() => message;
}

class TokenStorage {
  static const _key = 'auth_token';
  final _storage = const FlutterSecureStorage();

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}

class ApiClient {
  /// [dio] solo se inyecta en pruebas.
  ApiClient(this._tokens, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await _tokens.read();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }

  final TokenStorage _tokens;
  final Dio _dio;

  TokenStorage get tokens => _tokens;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? data}) =>
      _send(() => _dio.post(path, data: data));

  Future<Map<String, dynamic>> delete(String path) => _send(() => _dio.delete(path));

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      final body = response.data;
      return body is Map<String, dynamic> ? body : <String, dynamic>{};
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  ApiException _toException(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;

    if (status == 429) {
      return ApiException('Demasiados intentos seguidos. Espera un minuto e inténtalo de nuevo.', statusCode: 429);
    }

    if (body is Map) {
      final raw = body['errors'];
      final errors = <String, List<String>>{};
      if (raw is Map) {
        raw.forEach((key, value) => errors['$key'] = [for (final v in (value as List)) '$v']);
      }
      final first = errors.values.isNotEmpty ? errors.values.first.first : null;
      return ApiException(first ?? (body['message'] as String?) ?? 'Error del servidor', statusCode: status, errors: errors);
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return ApiException('No hay conexión con el servidor. Revisa tu internet.');
    }
    return ApiException('No se pudo completar la solicitud.', statusCode: status);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStorageProvider)));
