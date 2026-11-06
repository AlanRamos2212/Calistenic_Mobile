import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AchievementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool unlocked;

  const AchievementTile({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.card : AppColors.lockedCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked
              ? AppColors.blue.withValues(alpha: 0.25)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: unlocked ? AppColors.blue : AppColors.lockedIconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: unlocked ? Colors.white : Colors.black54,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: unlocked ? Colors.white : AppColors.subtext,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8, color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}
