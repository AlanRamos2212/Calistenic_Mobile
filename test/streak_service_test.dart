import 'package:calistenic_mobile/features/home/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakService.computeStreak', () {
    final now = DateTime(2026, 11, 15); // domingo

    test('returns 0 when there are no training days', () {
      expect(StreakService.computeStreak(const [], now: now), 0);
    });

    test('counts consecutive days ending today', () {
      final dates = [
        DateTime(2026, 11, 15),
        DateTime(2026, 11, 14),
        DateTime(2026, 11, 13),
      ];
      expect(StreakService.computeStreak(dates, now: now), 3);
    });

    test('keeps an active streak when today has no workout yet', () {
      final dates = [
        DateTime(2026, 11, 14),
        DateTime(2026, 11, 13),
      ];
      expect(StreakService.computeStreak(dates, now: now), 2);
    });

    test('breaks the streak after a rest day', () {
      final dates = [
        DateTime(2026, 11, 13),
        DateTime(2026, 11, 12),
      ];
      expect(StreakService.computeStreak(dates, now: now), 0);
    });

    test('returns 0 when the last workout is more than one day old', () {
      final dates = [DateTime(2026, 11, 11)];
      expect(StreakService.computeStreak(dates, now: now), 0);
    });

    test('counts sessions on the same day only once', () {
      final dates = [
        DateTime(2026, 11, 15, 7, 30),
        DateTime(2026, 11, 15, 20, 10),
      ];
      expect(StreakService.computeStreak(dates, now: now), 1);
    });

    test('ignores time-of-day when bucketing into days', () {
      final dates = [
        DateTime(2026, 11, 14, 23, 59),
        DateTime(2026, 11, 15, 0, 5),
      ];
      expect(StreakService.computeStreak(dates, now: now), 2);
    });
  });

  group('StreakService.parseSessionDates', () {
    test('parses ISO 8601 startedAt values from WearableSessionResponse',
        () {
      final sessions = [
        {'id': 1, 'startedAt': '2026-11-14T22:30:00-06:00'},
        {'id': 2, 'startedAt': '2026-11-15T08:00:00Z'},
      ];

      final dates = StreakService.parseSessionDates(sessions);

      expect(dates, hasLength(2));
      // Local day bucketing, not raw UTC strings.
      expect(
        dates.every(
          (d) => d.year == 2026 && (d.month == 11) && d.day >= 14 && d.day <= 15,
        ),
        isTrue,
      );
    });

    test('ignores malformed or missing startedAt values', () {
      final sessions = [
        {'id': 1},
        {'id': 2, 'startedAt': ''},
        {'id': 3, 'startedAt': 'not-a-date'},
        {'id': 4, 'startedAt': '2026-11-14T10:00:00Z'},
        'not-an-object',
      ];

      final dates = StreakService.parseSessionDates(sessions);

      expect(dates, hasLength(1));
    });
  });
}
