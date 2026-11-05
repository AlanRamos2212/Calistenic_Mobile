/// Comment mapped from `CommentResponse` (`GET /api/posts/{id}/comments`).
class CommentModel {
  final String id;
  final String userName;
  final String? userAvatarUrl;
  final String content;
  final DateTime? createdAt;

  const CommentModel({
    required this.id,
    required this.userName,
    this.userAvatarUrl,
    required this.content,
    this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['commentId'];
    final name = '${json['userName'] ?? ''}'.trim();
    final avatar = '${json['userAvatar'] ?? ''}'.trim();
    return CommentModel(
      id: '$rawId',
      userName: name.isNotEmpty ? name : 'Usuario',
      userAvatarUrl: avatar.isNotEmpty ? avatar : null,
      content: '${json['content'] ?? ''}'.trim(),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal(),
    );
  }
}
