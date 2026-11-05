import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_cache.dart';
import '../models/exercise_model.dart';

/// Fetches the exercise catalog from `GET /api/exercises` with offline caching.
class ExerciseService {
  ExerciseService({http.Client? client, FlutterSecureStorage? storage})
    : _api = ApiClient(client: client, storage: storage),
      _cache = LocalCache(storage: storage);

  final ApiClient _api;
  final LocalCache _cache;

  /// Returns cached exercises immediately, or an empty list if none exist.
  Future<List<ExerciseModel>> getCached() async {
    final cached = await _cache.getJson(ApiConstants.cacheExercises);
    if (cached is List) {
      return cached
          .whereType<Map<String, dynamic>>()
          .map(ExerciseModel.fromJson)
          .toList();
    }
    return const [];
  }

  /// Downloads exercises from the backend and persists them to local cache.
  Future<List<ExerciseModel>> fetchAndCache() async {
    final data = await _api.get(ApiConstants.exercises);
    if (data is! List) {
      throw const ApiException('El servidor devolvió una respuesta inválida.');
    }
    await _cache.saveJson(ApiConstants.cacheExercises, data);
    return data
        .whereType<Map<String, dynamic>>()
        .map(ExerciseModel.fromJson)
        .toList();
  }

  /// Returns exercises from the network, falling back to local cache only on connection drop.
  Future<List<ExerciseModel>> list() async {
    try {
      return await fetchAndCache();
    } on ApiException catch (e) {
      // Propagate explicit HTTP errors (like 401, 503) from the server.
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
