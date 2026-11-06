import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_cache.dart';
import '../models/custom_routine_model.dart';
import '../models/routine_detail_model.dart';

/// Persists the user's own routines under `/api/user-routines`
/// (creates, lists, loads details and deletes with offline-first cache).
class CustomRoutineService {
  CustomRoutineService({http.Client? client, FlutterSecureStorage? storage})
    : _api = ApiClient(client: client, storage: storage),
      _cache = LocalCache(storage: storage);

  final ApiClient _api;
  final LocalCache _cache;

  // ---- List (summary cards) -------------------------------------------

  Future<List<CustomRoutineModel>> getCached() async {
    final cached = await _cache.getJson(ApiConstants.cacheUserRoutines);
    if (cached is List) {
      return cached
          .whereType<Map<String, dynamic>>()
          .map(CustomRoutineModel.fromJson)
          .toList();
    }
    return const [];
  }

  Future<List<CustomRoutineModel>> fetchAndCache() async {
    final data = await _api.get(ApiConstants.userRoutines);
    if (data is! List) {
      throw const ApiException('El servidor devolvió una respuesta inválida.');
    }
    await _cache.saveJson(ApiConstants.cacheUserRoutines, data);
    return data
        .whereType<Map<String, dynamic>>()
        .map(CustomRoutineModel.fromJson)
        .toList();
  }

  /// Network first, cache fallback on connection drop.
  Future<List<CustomRoutineModel>> list() async {
    try {
      return await fetchAndCache();
    } catch (_) {
      final cached = await getCached();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  // ---- Detail ----------------------------------------------------------

  /// Reuses [RoutineDetailModel] so the runner consumes it directly.
  Future<RoutineDetailModel> detail(String id) async {
    try {
      final data = await _api.get(ApiConstants.userRoutineDetail(id));
      return await _parseDetail(data, id);
    } on ApiException catch (e) {
      if (e.statusCode != null) rethrow;
      return _cachedDetailOrThrow(id);
    } catch (_) {
      return _cachedDetailOrThrow(id);
    }
  }

  Future<RoutineDetailModel> _cachedDetailOrThrow(String id) async {
    final cached = await _cache.getJson(ApiConstants.cacheUserRoutineDetail(id));
    if (cached is Map<String, dynamic>) return RoutineDetailModel.fromJson(cached);
    throw const ApiException('La rutina no está disponible sin conexión.');
  }

  // ---- Create ----------------------------------------------------------

  /// Persists [draft]; returns the routine detail as stored by the backend.
  Future<RoutineDetailModel> create({
    required String title,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final data = await _api.post(ApiConstants.userRoutines, body: {
      'title': title,
      'exercises': exercises,
    });
    final detail = await _parseDetail(data, null);
    // Refresh the card list in cache best-effort (list may have changed).
    try {
      await fetchAndCache();
    } catch (_) {}
    return detail;
  }

  Future<void> delete(String id) async {
    await _api.delete(ApiConstants.userRoutineDetail(id));
    await _cache.remove(ApiConstants.cacheUserRoutineDetail(id));
    try {
      await fetchAndCache();
    } catch (_) {}
  }

  Future<RoutineDetailModel> _parseDetail(dynamic data, String? id) async {
    if (data is! Map<String, dynamic>) {
      throw const ApiException('El servidor devolvió una respuesta inválida.');
    }
    if (id != null) {
      await _cache.saveJson(ApiConstants.cacheUserRoutineDetail(id), data);
    }
    return RoutineDetailModel.fromJson(data);
  }
}
