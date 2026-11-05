import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../features/social/models/post_model.dart';
import '../../features/social/utils/relative_time.dart';

/// Feed post entry: author portrait (photo or initials), relative timestamp,
/// optional attached image and social actions (like, comments, share).
class PostCard extends StatelessWidget {
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final String? imageUrl;
  final DateTime? createdAt;
  final String? achievement;
  final int likes;
  final int comments;
  final bool liked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final bool canDelete;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
    this.imageUrl,
    this.createdAt,
    this.achievement,
    this.likes = 0,
    this.comments = 0,
    this.liked = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImage = absoluteUrl(imageUrl);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AuthorAvatar(url: authorAvatarUrl, name: authorName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null)
                      Text(
                        RelativeTime.format(createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.subtext),
                      ),
                  ],
                ),
              ),
              if (canDelete)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: AppColors.subtext),
                  onSelected: (value) {
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar publicación'),
                    ),
                  ],
                )
              else
                const Icon(Icons.more_horiz, color: AppColors.subtext),
            ],
          ),
          const SizedBox(height: 14),
          if (resolvedImage != null) ...[
            _PostImage(url: resolvedImage),
            const SizedBox(height: 14),
          ],
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (achievement != null && achievement!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              achievement!,
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: liked ? Colors.redAccent : null,
                ),
                onPressed: onLike,
              ),
              if (likes > 0)
                Text(
                  '$likes',
                  style: const TextStyle(fontSize: 12, color: AppColors.subtext),
                ),
              const SizedBox(width: 16),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                onPressed: onComment,
              ),
              if (comments > 0)
                Text(
                  '$comments',
                  style: const TextStyle(fontSize: 12, color: AppColors.subtext),
                ),
              const SizedBox(width: 16),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final String? url;
  final String name;

  const _AuthorAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final resolved = absoluteUrl(url);
    if (resolved == null) return _initials();
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _initials(),
        placeholder: (_, _) => Container(
          width: 36,
          height: 36,
          color: AppColors.cardBorder.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _initials() => CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.blue,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'A',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      );
}

class _PostImage extends StatelessWidget {
  final String url;

  const _PostImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              color: AppColors.cardBorder.withValues(alpha: 0.3),
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, _, _) => Container(
              color: AppColors.cardBorder.withValues(alpha: 0.3),
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black87,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
