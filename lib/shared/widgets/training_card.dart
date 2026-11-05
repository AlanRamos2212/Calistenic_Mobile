import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class TrainingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback? onTap;

  const TrainingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.blueGradientStart,
              AppColors.blueGradientEnd,
            ],
          ),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              meta,
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.subtext),
            ),
            const Align(
              alignment: Alignment.bottomRight,
              child: Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
