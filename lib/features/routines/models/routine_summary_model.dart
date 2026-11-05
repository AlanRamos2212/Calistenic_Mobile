/// Routine summary card mapped from `RoutineResponse` (`GET /api/routines`).
class RoutineSummaryModel {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String level;
  final int? durationMin;
  final int? estimatedCalories;
  final String? coverImageUrl;
  final int exerciseCount;

  const RoutineSummaryModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.level,
    this.durationMin,
    this.estimatedCalories,
    this.coverImageUrl,
    this.exerciseCount = 0,
  });

  /// Human meta line, e.g. "30 min · 400 kcal · 3 ejercicios".
  String get meta {
    final parts = <String>[];
    if (durationMin != null) parts.add('$durationMin min');
    if (estimatedCalories != null) parts.add('$estimatedCalories kcal');
    parts.add('$exerciseCount ejercicios');
    return parts.join(' · ');
  }

  factory RoutineSummaryModel.fromJson(Map<String, dynamic> json) {
    return RoutineSummaryModel(
      id: '${json['id'] ?? json['routineId']}',
      title: '${json['title'] ?? 'Rutina'}'.trim(),
      subtitle: '${json['subtitle'] ?? ''}'.trim(),
      category: '${json['category'] ?? ''}'.trim(),
      level: '${json['level'] ?? ''}'.trim(),
      durationMin: _intOrNull(json['durationMin']),
      estimatedCalories: _intOrNull(json['estimatedCalories']),
      coverImageUrl: _stringOrNull(json['coverImageUrl']),
      exerciseCount: _int(json['exerciseCount']),
    );
  }

  static int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
  static int? _intOrNull(Object? v) => v == null ? null : _int(v);
  static String? _stringOrNull(Object? v) {
    final s = '$v'.trim();
    return (s.isEmpty || s == 'null') ? null : s;
  }
}
