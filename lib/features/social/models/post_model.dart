import '../../../core/constants/api_constants.dart';

/// Post mapped from `PostResponse` (`GET /api/posts`).
class PostModel {
  final String id;
  final String authorName;
  final int authorUserId;
  final String? authorAvatarUrl;
  final String content;
  final String? imageUrl;
  final DateTime? createdAt;
  final String? achievement;
  final int likes;
  final int comments;
  final bool likedByCurrentUser;

  const PostModel({
    required this.id,
    required this.authorName,
    this.authorUserId = 0,
    this.authorAvatarUrl,
    required this.content,
    this.imageUrl,
    this.createdAt,
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
      authorAvatarUrl: _string(json['userAvatar']),
      content: (json['content'] as String?) ?? '',
      imageUrl: _string(json['imageUrl']),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal(),
      // PostResponse has no achievement info yet; keep null so the UI does
      // not display fake badges.
      achievement: null,
      likes: _int(json['likesCount']),
      comments: _int(json['commentsCount']),
      likedByCurrentUser: json['likedByCurrentUser'] == true,
    );
  }

  static String? _string(Object? value) {
    final text = '$value'.trim();
    return (text.isEmpty || text == 'null') ? null : text;
  }

  static int _int(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  /// Copy with new like/comment state, keeping identity and author data.
  PostModel copyWith({
    int? likes,
    int? comments,
    bool? likedByCurrentUser,
  }) =>
      PostModel(
        id: id,
        authorName: authorName,
        authorUserId: authorUserId,
        authorAvatarUrl: authorAvatarUrl,
        content: content,
        imageUrl: imageUrl,
        createdAt: createdAt,
        achievement: achievement,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        likedByCurrentUser: likedByCurrentUser ?? this.likedByCurrentUser,
      );
}

/// Absolute URL helpers — backend returns paths like `/api/media/{file}`,
/// which need the API base host prepended to load them with `Image.network`.
extension PostUrls on PostModel {
  String? get resolvedAvatarUrl => absoluteUrl(authorAvatarUrl);
  String? get resolvedImageUrl => absoluteUrl(imageUrl);
}

String? absoluteUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  final base = Uri.parse(ApiConstants.baseUrl);
  final cleaned = path.startsWith('/api') ? path.substring(4) : path;
  return base.replace(path: '${base.path}$cleaned').toString();
}
