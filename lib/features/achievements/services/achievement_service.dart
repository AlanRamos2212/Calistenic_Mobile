import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_cache.dart';
import '../models/achievement_model.dart';

/// Fetches the authenticated user's unlocked achievements with offline caching.
class AchievementService {
  AchievementService({http.Client? client, FlutterSecureStorage? storage})
    : _api = ApiClient(client: client, storage: storage),
      _cache = LocalCache(storage: storage);

  final ApiClient _api;
  final LocalCache _cache;

  /// Returns cached achievements immediately, or an empty list if none exist.
  Future<List<AchievementModel>> getCached() async {
    final cached = await _cache.getJson(ApiConstants.cacheAchievements);
    if (cached is List) {
      return cached
          .whereType<Map<String, dynamic>>()
          .map(AchievementModel.fromJson)
          .toList();
    }
    return const [];
  }

  /// Downloads achievements and persists them to local cache.
  Future<List<AchievementModel>> fetchAndCache() async {
    final data = await _api.get(ApiConstants.achievements);
    if (data is! List) {
      throw const ApiException('El servidor devolvió una respuesta inválida.');
    }
    await _cache.saveJson(ApiConstants.cacheAchievements, data);
    return data
        .whereType<Map<String, dynamic>>()
        .map(AchievementModel.fromJson)
        .toList();
  }

  /// Returns achievements from the network, falling back to local cache only on connection drop.
  Future<List<AchievementModel>> list() async {
    try {
      return await fetchAndCache();
    } on ApiException catch (e) {
      // Propagate explicit HTTP errors (401, 503, etc.) from the server.
      if (e.statusCode != null) {
        rethrow;
      }
      final cached = await getCached();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    } catch (e) {
      final cached = await getCached();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }
}
