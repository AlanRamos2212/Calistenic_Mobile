/// Summary card mapped from `UserRoutineResponse` (`GET /api/user-routines`).
class CustomRoutineModel {
  final String id;
  final String title;
  final int exerciseCount;
  final int totalSets;

  const CustomRoutineModel({
    required this.id,
    required this.title,
    this.exerciseCount = 0,
    this.totalSets = 0,
  });

  /// "2 ejercicios · 7 series"
  String get meta => '$exerciseCount ejercicios · $totalSets series';

  factory CustomRoutineModel.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
    return CustomRoutineModel(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Mi rutina'}'.trim(),
      exerciseCount: asInt(json['exerciseCount']),
      totalSets: asInt(json['totalSets']),
    );
  }
}
