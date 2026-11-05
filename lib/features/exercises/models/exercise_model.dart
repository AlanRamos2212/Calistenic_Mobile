/// Exercise entity mapped from the Spring Boot `Exercise` entity
/// (`GET /api/exercises`).
class ExerciseModel {
  final int id;
  final String name;
  final String? description;
  final String category;
  final String level;
  final int? durationMin;
  final List<String> muscles;
  final String? imageUrl;
  final String? gifUrl;
  final String? techniqueDescription;

  const ExerciseModel({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.level,
    this.durationMin,
    this.muscles = const [],
    this.imageUrl,
    this.gifUrl,
    this.techniqueDescription,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['exerciseId'];
    final name = json['name'] ?? json['title'];
    return ExerciseModel(
      id: id is num ? id.toInt() : int.tryParse('$id') ?? 0,
      name: name is String ? name : '',
      description: json['description'] as String?,
      category: (json['category'] as String?) ?? 'General',
      level: (json['level'] as String?) ?? '',
      durationMin: _intOrNull(json['durationMin']),
      muscles: _parseMuscles(json['muscles']),
      imageUrl: json['imageUrl'] as String?,
      gifUrl: json['gifUrl'] as String?,
      techniqueDescription: json['techniqueDescription'] as String?,
    );
  }

  static int? _intOrNull(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  /// Backend stores muscles as a comma-separated string, but tolerates a JSON
  /// array too (defensive against future contract changes).
  static List<String> _parseMuscles(Object? value) {
    if (value is List) {
      return value.whereType<String>().map((e) => e.trim()).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
