import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_cache.dart';
import '../models/stats_model.dart';

/// Fetches the authenticated user's statistics from `GET /api/stats/user` with offline caching.
class StatsService {
  StatsService({http.Client? client, FlutterSecureStorage? storage})
    : _api = ApiClient(client: client, storage: storage),
      _cache = LocalCache(storage: storage);

  final ApiClient _api;
  final LocalCache _cache;

  /// Returns cached statistics immediately, or null if none exist.
  Future<UserStats?> getCached() async {
    final cached = await _cache.getJson(ApiConstants.cacheUserStats);
    if (cached is Map<String, dynamic>) {
      return UserStats.fromJson(cached);
    }
    return null;
  }

  /// Downloads statistics from the backend and persists them to local cache.
  Future<UserStats> fetchAndCache() async {
    final data = await _api.get(ApiConstants.statsUser);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('El servidor devolvió una respuesta inválida.');
    }
    await _cache.saveJson(ApiConstants.cacheUserStats, data);
    return UserStats.fromJson(data);
  }

  /// Returns statistics from the network, falling back to local cache only on connection drop.
  Future<UserStats> fetch() async {
    try {
      return await fetchAndCache();
    } on ApiException catch (e) {
      // Propagate explicit HTTP errors (401, 503, etc.) from the server.
      if (e.statusCode != null) {
        rethrow;
      }
      final cached = await getCached();
      if (cached != null) {
        return cached;
      }
      rethrow;
    } catch (e) {
      final cached = await getCached();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }
}
