import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.blue,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}
