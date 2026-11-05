/// Routine detail mapped from `RoutineDetailResponse` (`GET /api/routines/{id}`).
class RoutineDetailModel {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String level;
  final int? durationMin;
  final int? estimatedCalories;
  final String? coverImageUrl;
  final List<RoutineExerciseItem> exercises;

  const RoutineDetailModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.level,
    this.durationMin,
    this.estimatedCalories,
    this.coverImageUrl,
    required this.exercises,
  });

  factory RoutineDetailModel.fromJson(Map<String, dynamic> json) {
    return RoutineDetailModel(
      id: '${json['id']}',
      title: '${json['title'] ?? 'Rutina'}'.trim(),
      subtitle: '${json['subtitle'] ?? ''}'.trim(),
      category: '${json['category'] ?? ''}'.trim(),
      level: '${json['level'] ?? ''}'.trim(),
      durationMin: _intOrNull(json['durationMin']),
      estimatedCalories: _intOrNull(json['estimatedCalories']),
      coverImageUrl: _stringOrNull(json['coverImageUrl']),
      exercises: ((json['exercises'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RoutineExerciseItem.fromJson)
          .toList(),
    );
  }

  static int? _intOrNull(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse('$v') ?? 0);
  static String? _stringOrNull(Object? v) {
    final s = '$v'.trim();
    return (s.isEmpty || s == 'null') ? null : s;
  }
}

/// One exercise inside a routine: DB order plus training prescription.
class RoutineExerciseItem {
  final String id;
  final String name;
  final String? imageUrl;
  final String? gifUrl;
  final String? techniqueDescription;
  final String category;
  final String level;
  final String? muscles;
  final int? estimatedCalories;
  final int position;
  final int sets;
  final int? reps;
  final int restSeconds;

  const RoutineExerciseItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.gifUrl,
    this.techniqueDescription,
    required this.category,
    required this.level,
    this.muscles,
    this.estimatedCalories,
    required this.position,
    required this.sets,
    this.reps,
    this.restSeconds = 60,
  });

  /// "4 × 8" o "3 series" cuando el ejercicio es por tiempo.
  String get prescription =>
      reps == null ? '$sets series' : '$sets × $reps';

  String get prescriptionLabel =>
      reps == null ? '$sets series' : '$sets × $reps';

  String get restLabel => '$restSeconds s';

  factory RoutineExerciseItem.fromJson(Map<String, dynamic> json) {
    return RoutineExerciseItem(
      id: '${json['id']}',
      name: '${json['name'] ?? 'Ejercicio'}'.trim(),
      imageUrl: _stringOrNull(json['imageUrl']),
      gifUrl: _stringOrNull(json['gifUrl']),
      techniqueDescription: _stringOrNull(json['techniqueDescription']),
      category: '${json['category'] ?? ''}'.trim(),
      level: '${json['level'] ?? ''}'.trim(),
      muscles: _stringOrNull(json['muscles']),
      estimatedCalories: _intOrNull(json['estimatedCalories']),
      position: _int(json['position']),
      sets: _int(json['sets']).clamp(1, 20),
      reps: _intOrNull(json['reps']),
      restSeconds: _int(json['restSeconds']).clamp(0, 600),
    );
  }

  static int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
  static int? _intOrNull(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse('$v') ?? 0);
  static String? _stringOrNull(Object? v) {
    final s = '$v'.trim();
    return (s.isEmpty || s == 'null') ? null : s;
  }
}
