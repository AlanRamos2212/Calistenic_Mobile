import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../constants/api_constants.dart';
import 'api_exception.dart';

/// Authenticated HTTP client shared by the feature services.
///
/// - Injects the Bearer token from secure storage into every request.
/// - Applies request timeouts and automatic retries for flaky connections.
/// - Normalizes backend error responses into [ApiException].
class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  /// Returns the stored JWT token, or null if unauthenticated.
  Future<String?> readToken() => _storage.read(key: ApiConstants.tokenKey);

  Future<Map<String, String>> _authHeaders() async {
    final token = await readToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('No hay sesión activa.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Authenticated GET with automatic retry for flaky networks.
  Future<dynamic> get(String path, {int maxRetries = 2}) async {
    int attempts = 0;
    while (true) {
      try {
        final response = await _client
            .get(_uri(path), headers: await _authHeaders())
            .timeout(ApiConstants.requestTimeout);
        return _decode(response);
      } on ApiException {
        // Backend HTTP error status (4xx/5xx): do not retry, propagate directly.
        rethrow;
      } on TimeoutException {
        attempts++;
        if (attempts > maxRetries) {
          throw const ApiException('El servidor no respondió a tiempo.');
        }
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      } on http.ClientException {
        attempts++;
        if (attempts > maxRetries) {
          throw const ApiException('No se pudo conectar con el servidor.');
        }
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      } catch (e) {
        throw ApiException('Error inesperado: $e');
      }
    }
  }

  /// Authenticated POST with a JSON body.
  Future<dynamic> post(String path, {required Map<String, dynamic> body}) async {
    try {
      final response = await _client
          .post(
            _uri(path),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(ApiConstants.requestTimeout);
      return _decode(response);
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

  /// Authenticated PATCH with a JSON body.
  Future<dynamic> patch(String path, {required Map<String, dynamic> body}) async {
    try {
      final response = await _client
          .patch(
            _uri(path),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(ApiConstants.requestTimeout);
      return _decode(response);
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

  /// Authenticated multipart POST for file uploads.
  ///
  /// [fieldName] is the form-data field name the backend expects (e.g. "avatar").
  /// [fields] carries additional text form-data fields (e.g. {"content": "..."}).
  Future<dynamic> postMultipart(
    String path,
    File file,
    String fieldName, {
    Map<String, String> fields = const {},
  }) async {
    try {
      final token = await readToken();
      if (token == null || token.isEmpty) {
        throw const ApiException('No hay sesión activa.');
      }

      // Infer image MIME type from file extension
      final ext = file.path.split('.').last.toLowerCase();
      final subType = (ext == 'png' || ext == 'webp' || ext == 'gif')
          ? ext
          : 'jpeg'; // default to jpeg for jpg/other
      final mediaType = MediaType('image', subType);

      final request = http.MultipartRequest('POST', _uri(path))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields.addAll(fields)
        ..files.add(await http.MultipartFile.fromPath(
          fieldName,
          file.path,
          contentType: mediaType,
        ));

      final streamedResponse = await request.send().timeout(ApiConstants.requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _decode(response);
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

  Uri _uri(String path) => Uri.parse('${ApiConstants.baseUrl}$path');

  dynamic _decode(http.Response response) {
    if (response.statusCode == 401) {
      throw const ApiException(
        'Sesión expirada. Por favor ingresa de nuevo.',
        statusCode: 401,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
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
    return 'Error del servidor (HTTP ${response.statusCode}). Inténtalo de nuevo.';
  }
}
