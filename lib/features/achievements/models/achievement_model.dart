/// Achievement mapped from `AchievementResponse`
/// (`GET /api/achievements` — only the user's unlocked ones).
class AchievementModel {
  final String id;
  final String code;
  final String title;
  final String description;
  final String? unlockedAt;

  const AchievementModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    this.unlockedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['achievementId'];
    return AchievementModel(
      id: '$rawId',
      code: (json['code'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Logro',
      description: (json['description'] as String?) ?? '',
      unlockedAt: json['unlockedAt'] as String?,
    );
  }
}
