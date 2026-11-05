import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lightweight persistent local cache backed by FlutterSecureStorage.
///
/// Provides offline data persistence without requiring native database setups.
class LocalCache {
  final FlutterSecureStorage _storage;

  LocalCache({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Serializes and writes a JSON-compatible object to cache.
  Future<void> saveJson(String key, dynamic data) async {
    try {
      final jsonStr = jsonEncode(data);
      await _storage.write(key: key, value: jsonStr);
    } catch (_) {
      // Ignore cache write errors defensively so the app never crashes.
    }
  }

  /// Reads and deserializes a JSON object from cache, or returns null if not found.
  Future<dynamic> getJson(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null || value.isEmpty) return null;
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  /// Removes an item from cache.
  Future<void> remove(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}
