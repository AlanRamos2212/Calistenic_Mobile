import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../../social/models/post_model.dart';
import '../models/exercise_model.dart';
import '../../routines/screens/custom_routine_screen.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    this.onAddToRoutine,
  });

  final ExerciseModel exercise;
  final VoidCallback? onAddToRoutine;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = absoluteUrl(exercise.gifUrl ?? exercise.imageUrl);
    return FrameScaffold(
      title: 'Ejercicio',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            exercise.name,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '${exercise.level.toUpperCase()} · ${exercise.category.toUpperCase()}',
            style: const TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: mediaUrl == null
                ? _placeholder()
                : Image.network(
                    mediaUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  ),
          ),
          const SizedBox(height: 20),
          if (exercise.muscles.isNotEmpty) ...[
            const Text('MÚSCULOS', style: _HeadingStyle()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: exercise.muscles
                  .map((muscle) => _chip(muscle))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          if ((exercise.description ?? '').trim().isNotEmpty) ...[
            const Text('DESCRIPCIÓN', style: _HeadingStyle()),
            const SizedBox(height: 8),
            Text(
              exercise.description!,
              style: const TextStyle(color: AppColors.subtext, height: 1.45),
            ),
            const SizedBox(height: 20),
          ],
          if ((exercise.techniqueDescription ?? '').trim().isNotEmpty) ...[
            const Text('TÉCNICA', style: _HeadingStyle()),
            const SizedBox(height: 8),
            Text(
              exercise.techniqueDescription!,
              style: const TextStyle(color: Colors.white, height: 1.45),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.blue,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed:
                onAddToRoutine ??
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CustomRoutineBuilderScreen(
                      initialExercise: exercise,
                      availableExercises: const [],
                    ),
                  ),
                ),
            icon: const Icon(Icons.playlist_add),
            label: const Text(
              'Agregar a mi rutina',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 220,
    color: AppColors.card,
    alignment: Alignment.center,
    child: const Icon(Icons.fitness_center, color: AppColors.blue, size: 56),
  );

  static Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.subtext, fontSize: 12),
    ),
  );
}

class _HeadingStyle extends TextStyle {
  const _HeadingStyle()
    : super(
        color: AppColors.subtext,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      );
}
