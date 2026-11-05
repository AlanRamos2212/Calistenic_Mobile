import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_cache.dart';
import '../models/routine_detail_model.dart';
import '../models/routine_summary_model.dart';

/// Fetches routines from `GET /api/routines` with offline caching.
class RoutineService {
  RoutineService({http.Client? client, FlutterSecureStorage? storage})
    : _api = ApiClient(client: client, storage: storage),
      _cache = LocalCache(storage: storage);

  final ApiClient _api;
  final LocalCache _cache;

  /// Returns cached routine cards immediately, or an empty list if none exist.
  Future<List<RoutineSummaryModel>> getCached() async {
    final cached = await _cache.getJson(ApiConstants.cacheRoutines);
    if (cached is List) {
      return cached
          .whereType<Map<String, dynamic>>()
          .map(RoutineSummaryModel.fromJson)
          .toList();
    }
    return const [];
  }

  /// Downloads routines from the backend and persists them to local cache.
  Future<List<RoutineSummaryModel>> fetchAndCache() async {
    final data = await _api.get(ApiConstants.routines);
    if (data is! List) {
      throw const ApiException('El servidor devolvió una respuesta inválida.');
    }
    await _cache.saveJson(ApiConstants.cacheRoutines, data);
    return data
        .whereType<Map<String, dynamic>>()
        .map(RoutineSummaryModel.fromJson)
        .toList();
  }

  /// Routines from the network, falling back to local cache on connection drop.
  Future<List<RoutineSummaryModel>> list() async {
    try {
      return await fetchAndCache();
    } on ApiException catch (e) {
      if (e.statusCode != null) rethrow;
      final cached = await getCached();
      if (cached.isNotEmpty) return cached;
      rethrow;
    } catch (e) {
      final cached = await getCached();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  /// Returns a cached routine detail, or null if it has never been loaded.
  Future<RoutineDetailModel?> getCachedDetail(String id) async {
    final cached = await _cache.getJson(ApiConstants.cacheRoutineDetail(id));
    if (cached is Map<String, dynamic>) return RoutineDetailModel.fromJson(cached);
    return null;
  }

  /// Loads one routine with its ordered exercises, caching the result.
  ///
  /// Falls back to the latest cached copy when the connection drops.
  Future<RoutineDetailModel> detail(String id) async {
    try {
      final data = await _api.get(ApiConstants.routineDetail(id));
      if (data is! Map<String, dynamic>) {
        throw const ApiException('El servidor devolvió una respuesta inválida.');
      }
      await _cache.saveJson(ApiConstants.cacheRoutineDetail(id), data);
      return RoutineDetailModel.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode != null) rethrow;
      final cached = await getCachedDetail(id);
      if (cached != null) return cached;
      rethrow;
    } catch (e) {
      final cached = await getCachedDetail(id);
      if (cached != null) return cached;
      rethrow;
    }
  }
}
