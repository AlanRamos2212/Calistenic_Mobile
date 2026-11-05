import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class MetricCard extends StatelessWidget {
  final String value;
  final String label;

  const MetricCard({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.blue,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.subtext,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
