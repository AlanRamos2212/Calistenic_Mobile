import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth.access_token';
  static final _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8083/api',
  ).replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<void> login({required String email, required String password}) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    await _saveToken(response);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
    await _saveToken(response);
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> logout() => _storage.delete(key: _tokenKey);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(_errorMessage(response));
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw const AuthException(
          'El servidor devolvió una respuesta inválida.',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const AuthException(
          'El servidor devolvió una respuesta inválida.',
        );
      }
      final token = decoded['token'];
      if (token is! String || token.isEmpty) {
        throw const AuthException(
          'El servidor devolvió una respuesta inválida.',
        );
      }

      return decoded;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException('El servidor no respondió a tiempo.');
    } on http.ClientException {
      throw const AuthException('No se pudo conectar con el servidor.');
    } on FormatException {
      throw const AuthException('La dirección del servidor no es válida.');
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          decoded['message'] is String &&
          (decoded['message'] as String).trim().isNotEmpty) {
        return (decoded['message'] as String).trim();
      }
      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
    } on FormatException {
      if (response.body.trim().isNotEmpty) return response.body.trim();
    }

    return 'Error del servidor (HTTP ${response.statusCode}). Inténtalo de nuevo.';
  }

  Future<void> _saveToken(Map<String, dynamic> response) {
    return _storage.write(key: _tokenKey, value: response['token'] as String);
  }
}
