/// User statistics mapped from `UserStatsResponse`
/// (`GET /api/stats/user`).
class UserStats {
  final int totalWorkouts;
  final int totalMinutes;
  final int avgBpm;
  final List<ChartPoint> weeklySeries;
  final List<ChartPoint> bpmSeries;

  const UserStats({
    required this.totalWorkouts,
    required this.totalMinutes,
    required this.avgBpm,
    this.weeklySeries = const [],
    this.bpmSeries = const [],
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalWorkouts: _int(json['totalWorkouts']),
        totalMinutes: _int(json['totalMinutes']),
        avgBpm: _int(json['avgBpm']),
        weeklySeries: _points(json['weeklySeries']),
        bpmSeries: _points(json['bpmSeries']),
      );

  static int _int(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static List<ChartPoint> _points(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((point) => ChartPoint(
              label: point['label'] as String? ?? '',
              value: (point['value'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }
}

/// `{label, value}` pair used by the backend chart series.
class ChartPoint {
  final String label;
  final double value;

  const ChartPoint({required this.label, required this.value});
}
