import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PostCard extends StatelessWidget {
  final String authorName;
  final String content;
  final String? achievement;
  final int likes;
  final int comments;
  final bool liked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  const PostCard({
    super.key,
    required this.authorName,
    required this.content,
    this.achievement,
    this.likes = 0,
    this.comments = 0,
    this.liked = false,
    this.onLike,
    this.onComment,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
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
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.blue,
                child: Text(
                  authorName.isNotEmpty ? authorName[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                authorName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, color: AppColors.subtext),
            ],
          ),
          const SizedBox(height: 14),
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
