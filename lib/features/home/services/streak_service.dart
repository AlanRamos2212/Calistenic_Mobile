import 'package:home_widget/home_widget.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Streak (racha) source of truth for the Android home screen widget.
///
/// The widget runs in a native process and CANNOT read
/// `flutter_secure_storage` (it is encrypted with the app Keystore). The
/// streak is therefore stored through `HomeWidget.saveWidgetData`, which
/// writes to a SharedPreferences file that `StreakWidgetProvider` receives
/// directly in `onUpdate` as `widgetData`.
///
/// The streak is computed from real backend training sessions
/// (`GET /api/wearable-sessions`, field `startedAt`). If the backend is
/// unreachable, the last saved value is kept untouched.
class StreakService {
  StreakService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  static const String streakKey = 'streak_days';
  static const String updatedAtKey = 'streak_updated_at';

  /// Fully qualified name of the Android AppWidgetProvider, matching
  /// `android/app/src/main/AndroidManifest.xml`.
  static const String androidWidgetName = 'StreakWidgetProvider';

  /// Reads the streak currently visible on the home screen widget.
  Future<int> readStreak() async {
    final value = await HomeWidget.getWidgetData<String>(streakKey);
    return int.tryParse(value ?? '') ?? 0;
  }

  /// Persists the streak for the widget and triggers a widget refresh.
  Future<void> saveStreak(int days) async {
    final positive = days < 0 ? 0 : days;
    await HomeWidget.saveWidgetData<int>(streakKey, positive);
    await HomeWidget.saveWidgetData<String>(
      updatedAtKey,
      DateTime.now().toIso8601String(),
    );
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  /// Fetches the user's sessions from the backend, computes the streak and
  /// saves it for the widget.
  ///
  /// Returns the new streak, or the previous stored value when the backend
  /// fails (network/server errors) so the widget never regresses because of a
  /// temporary outage.
  Future<int> refreshFromBackend() async {
    try {
      final data = await _api.get(ApiConstants.wearableSessions);
      final dates = parseSessionDates(data is List ? data : const []);
      final streak = computeStreak(dates);
      await saveStreak(streak);
      return streak;
    } on ApiException {
      // Keep the last saved streak; the widget keeps showing previous data.
      return readStreak();
    } catch (e) {
      return readStreak();
    }
  }

  /// Extracts session start dates from a raw
  /// `List<WearableSessionResponse>` JSON list.
  static List<DateTime> parseSessionDates(List<dynamic> sessions) {
    final dates = <DateTime>[];
    for (final session in sessions) {
      if (session is! Map<String, dynamic>) continue;
      final raw = session['startedAt'];
      if (raw is! String || raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) dates.add(parsed.toLocal());
    }
    return dates;
  }

  /// Counts consecutive training days ending today (or yesterday when the
  /// user has not trained yet today — an active streak must not break at
  /// midnight before the next workout).
  ///
  /// Pure function, unit tested in test/streak_service_test.dart.
  static int computeStreak(Iterable<DateTime> dates, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = _dateOnly(reference);
    final trainingDays = dates.map(_dateOnly).toSet();

    var cursor = today;
    if (!trainingDays.contains(cursor)) {
      final yesterday = cursor.subtract(const Duration(days: 1));
      if (!trainingDays.contains(yesterday)) return 0;
      cursor = yesterday;
    }

    var streak = 0;
    while (trainingDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
