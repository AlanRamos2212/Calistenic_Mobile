import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Logs a workout to the backend as wearable sessions
/// (`/wearable-sessions/start`, `/metrics`, `/stop`).
///
/// One session is created per exercise, opened when its first set is
/// completed so we never leave orphan sessions when the user quits early.
class WorkoutService {
  WorkoutService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  /// Opens a session for [exerciseId]; returns its server id.
  ///
  /// wearableId is omitted: workouts can be logged without a wrist device.
  Future<int> startSession(int exerciseId) async {
    final data = await _api.post(ApiConstants.sessionStart, body: {
      'exerciseId': exerciseId,
    });
    if (data is! Map<String, dynamic>) {
      throw const ApiException(
          'El servidor devolvió una respuesta inválida al iniciar la sesión.');
    }
    final id = data['id'];
    if (id is int) return id;
    return int.tryParse('$id') ?? (throw const ApiException(
        'No se pudo leer el id de la sesión de entrenamiento.'));
  }

  /// Closes the session with the honest metrics measured by the UI:
  /// duration and estimated calories; no heart-rate samples exist so the
  /// HR fields are left null on purpose.
  Future<void> stopSession(
    int sessionId, {
    required int durationSec,
    required double caloriesBurned,
  }) async {
    await _api.post(ApiConstants.sessionStop('$sessionId'), body: {
      'endedAt': DateTime.now().toUtc().toIso8601String(),
      'durationSec': durationSec,
      'caloriesBurned': caloriesBurned,
    });
  }
}
