/// Post mapped from `PostResponse` (`GET /api/posts`).
class PostModel {
  final String id;
  final String authorName;
  final int authorUserId;
  final String content;
  final String? achievement;
  final int likes;
  final int comments;
  final bool likedByCurrentUser;

  const PostModel({
    required this.id,
    required this.authorName,
    this.authorUserId = 0,
    required this.content,
    this.achievement,
    this.likes = 0,
    this.comments = 0,
    this.likedByCurrentUser = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['postId'];
    return PostModel(
      id: '$rawId',
      authorUserId: _int(json['userId']),
      authorName: (json['userName'] as String?)?.trim().isNotEmpty == true
          ? (json['userName'] as String).trim()
          : 'Usuario',
      content: (json['content'] as String?) ?? '',
      // PostResponse has no achievement info yet; keep null so the UI does
      // not display fake badges.
      achievement: null,
      likes: _int(json['likesCount']),
      comments: _int(json['commentsCount']),
      likedByCurrentUser: json['likedByCurrentUser'] == true,
    );
  }

  static int _int(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;
}
