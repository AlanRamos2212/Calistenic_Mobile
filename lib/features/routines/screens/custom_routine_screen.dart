import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../../exercises/models/exercise_model.dart';
import '../../social/models/post_model.dart';
import 'workout_runner_screen.dart';
import '../models/routine_detail_model.dart';

class CustomRoutineDraft {
  const CustomRoutineDraft({required this.name, required this.exercises});

  final String name;
  final List<ExerciseModel> exercises;

  String get meta => '${exercises.length} ejercicios · rutina personal';
}

class CustomRoutineBuilderScreen extends StatefulWidget {
  const CustomRoutineBuilderScreen({
    super.key,
    required this.initialExercise,
    required this.availableExercises,
  });

  final ExerciseModel initialExercise;
  final List<ExerciseModel> availableExercises;

  @override
  State<CustomRoutineBuilderScreen> createState() =>
      _CustomRoutineBuilderScreenState();
}

class _CustomRoutineBuilderScreenState
    extends State<CustomRoutineBuilderScreen> {
  late final TextEditingController _nameController = TextEditingController(
    text: 'Mi rutina',
  );
  late final List<ExerciseModel> _selected = [widget.initialExercise];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addExercise(ExerciseModel exercise) {
    if (_selected.any((item) => item.id == exercise.id)) return;
    setState(() => _selected.add(exercise));
  }

  Future<void> _chooseExercise() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: widget.availableExercises.map((exercise) {
            final added = _selected.any((item) => item.id == exercise.id);
            return ListTile(
              enabled: !added,
              leading: Icon(
                added ? Icons.check : Icons.add_circle_outline,
                color: added ? AppColors.subtext : AppColors.blue,
              ),
              title: Text(exercise.name),
              subtitle: Text(exercise.category),
              onTap: () {
                _addExercise(exercise);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selected.isEmpty) return;
    Navigator.pop(
      context,
      CustomRoutineDraft(name: name, exercises: List.of(_selected)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FrameScaffold(
      title: 'Crear rutina',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Construye tu sesión',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Elige varios ejercicios y guárdalos juntos en tu carrusel.',
            style: TextStyle(color: AppColors.subtext),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Nombre de la rutina',
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 20),
          ..._selected.asMap().entries.map(
            (entry) => _SelectedExerciseTile(
              index: entry.key + 1,
              exercise: entry.value,
              onRemove: _selected.length == 1
                  ? null
                  : () => setState(() => _selected.removeAt(entry.key)),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _chooseExercise,
            icon: const Icon(Icons.add),
            label: const Text('Añadir otro ejercicio'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _save,
              child: const Text(
                'Guardar en mis rutinas',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomRoutineDetailScreen extends StatelessWidget {
  const CustomRoutineDetailScreen({super.key, required this.draft});

  final CustomRoutineDraft draft;

  RoutineDetailModel _runnerDetail() => RoutineDetailModel(
    id: 'local-${draft.name}',
    title: draft.name,
    subtitle: 'Rutina creada por ti',
    category: 'personalizada',
    level: 'personalizada',
    durationMin: draft.exercises.length * 8,
    estimatedCalories: draft.exercises.length * 60,
    exercises: draft.exercises.asMap().entries.map((entry) {
      final e = entry.value;
      return RoutineExerciseItem(
        id: '${e.id}',
        name: e.name,
        imageUrl: e.imageUrl,
        gifUrl: e.gifUrl,
        techniqueDescription: e.techniqueDescription,
        category: e.category,
        level: e.level,
        muscles: e.muscles.join(','),
        position: entry.key + 1,
        sets: 3,
        reps: 10,
        restSeconds: 60,
      );
    }).toList(),
  );

  @override
  Widget build(BuildContext context) {
    return FrameScaffold(
      title: draft.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rutina personalizada',
            style: TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(draft.meta, style: const TextStyle(color: AppColors.subtext)),
          const SizedBox(height: 20),
          ...draft.exercises.asMap().entries.map(
            (entry) => _SelectedExerciseTile(
              index: entry.key + 1,
              exercise: entry.value,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorkoutRunnerScreen(detail: _runnerDetail()),
                ),
              ),
              child: const Text(
                'Comenzar rutina',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedExerciseTile extends StatelessWidget {
  const _SelectedExerciseTile({
    required this.index,
    required this.exercise,
    this.onRemove,
  });

  final int index;
  final ExerciseModel exercise;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final image = absoluteUrl(exercise.gifUrl ?? exercise.imageUrl);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image == null
                ? const SizedBox(
                    width: 54,
                    height: 54,
                    child: Icon(Icons.fitness_center, color: AppColors.blue),
                  )
                : Image.network(
                    image,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$index. ${exercise.name}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (onRemove != null)
            IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class CustomRoutineCard extends StatelessWidget {
  const CustomRoutineCard({
    super.key,
    required this.draft,
    required this.onTap,
  });

  final CustomRoutineDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.blueGradientStart, AppColors.blueGradientEnd],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'MI RUTINA',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            draft.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          Text(
            draft.meta,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
