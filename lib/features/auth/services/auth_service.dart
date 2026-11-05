import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../models/auth_response.dart';

/// Legacy alias to preserve backwards compatibility.
typedef AuthException = ApiException;

class AuthService {
  AuthService({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  /// Authenticates a user with email and password.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(ApiConstants.login, {
      'email': email,
      'password': password,
    });
    final auth = AuthResponse.fromJson(response);
    await _saveAuthData(auth);
    return auth;
  }

  /// Registers a new user.
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _post(ApiConstants.register, {
      'name': name,
      'email': email,
      'password': password,
    });
    final auth = AuthResponse.fromJson(response);
    await _saveAuthData(auth);
    return auth;
  }

  /// Returns the stored JWT token, or null if unauthenticated.
  Future<String?> readToken() => _storage.read(key: ApiConstants.tokenKey);

  /// Checks if there is an active session stored.
  Future<bool> isAuthenticated() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }

  /// Returns the cached user name.
  Future<String?> getUserName() => _storage.read(key: ApiConstants.userNameKey);

  /// Returns the cached user email.
  Future<String?> getUserEmail() => _storage.read(key: ApiConstants.userEmailKey);

  /// Returns the cached user role.
  Future<String?> getUserRole() => _storage.read(key: ApiConstants.userRoleKey);

  /// Logs out the user by deleting all stored authentication credentials.
  /// Spring Boot JWT is stateless, so clearing client storage terminates the session.
  Future<void> logout() async {
    await Future.wait([
      _storage.delete(key: ApiConstants.tokenKey),
      _storage.delete(key: ApiConstants.userNameKey),
      _storage.delete(key: ApiConstants.userEmailKey),
      _storage.delete(key: ApiConstants.userRoleKey),
    ]);
  }

  /// Fetches the profile from `/api/auth/me` with Bearer token.
  Future<Map<String, dynamic>> fetchProfile() async {
    final token = await readToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No hay sesión activa.');
    }

    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.me}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 401) {
        await logout();
        throw const ApiException('Sesión expirada. Por favor ingresa de nuevo.', statusCode: 401);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_errorMessage(response), statusCode: response.statusCode);
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('El servidor no respondió a tiempo.');
    } on http.ClientException {
      throw const ApiException('No se pudo conectar con el servidor.');
    } catch (e) {
      throw ApiException('Error inesperado: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConstants.baseUrl}$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConstants.requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _errorMessage(response),
          statusCode: response.statusCode,
        );
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw const ApiException('El servidor devolvió una respuesta inválida.');
      }

      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('El servidor devolvió una respuesta inválida.');
      }

      final token = decoded['token'];
      if (token is! String || token.isEmpty) {
        throw const ApiException('El servidor no proporcionó un token de acceso.');
      }

      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('El servidor no respondió a tiempo.');
    } on http.ClientException {
      throw const ApiException('No se pudo conectar con el servidor.');
    } on FormatException {
      throw const ApiException('La dirección del servidor no es válida.');
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] is String &&
            (decoded['message'] as String).trim().isNotEmpty) {
          return (decoded['message'] as String).trim();
        }
        if (decoded['error'] is String &&
            (decoded['error'] as String).trim().isNotEmpty) {
          return (decoded['error'] as String).trim();
        }
      }
      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
    } on FormatException {
      if (response.body.trim().isNotEmpty) return response.body.trim();
    }

    if (response.statusCode == 401) {
      return 'Credenciales incorrectas o usuario no encontrado.';
    }
    if (response.statusCode == 409) {
      return 'Este correo ya se encuentra registrado.';
    }

    return 'Error del servidor (HTTP ${response.statusCode}). Inténtalo de nuevo.';
  }

  Future<void> _saveAuthData(AuthResponse auth) async {
    await Future.wait([
      _storage.write(key: ApiConstants.tokenKey, value: auth.token),
      if (auth.name.isNotEmpty)
        _storage.write(key: ApiConstants.userNameKey, value: auth.name),
      if (auth.email.isNotEmpty)
        _storage.write(key: ApiConstants.userEmailKey, value: auth.email),
      if (auth.role.isNotEmpty)
        _storage.write(key: ApiConstants.userRoleKey, value: auth.role),
    ]);
  }
}
