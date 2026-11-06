import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../../exercises/models/exercise_model.dart';
import '../../exercises/services/exercise_service.dart';
import '../../social/models/post_model.dart';
import 'workout_runner_screen.dart';
import '../models/custom_routine_model.dart';
import '../models/routine_detail_model.dart';
import '../services/custom_routine_service.dart';

/// Everything needed to persist a draft through `/api/user-routines`.
class CustomRoutineDraft {
  const CustomRoutineDraft({required this.title, required this.exercises});

  final String title;

  /// One entry per exercise: {exerciseId, sets, reps, restSeconds}.
  final List<Map<String, dynamic>> exercises;
}

/// Builder for a personalized routine: name + ordered exercises, each with
/// its own sets/reps. Persists via `CustomRoutineService.create` (button).
class CustomRoutineBuilderScreen extends StatefulWidget {
  const CustomRoutineBuilderScreen({
    super.key,
    required this.initialExercise,
    this.availableExercises = const [],
  });

  final ExerciseModel initialExercise;

  /// Catalog offered in the "add another" sheet. Falls back to the cached
  /// catalog when empty, so callers do not need to thread the list around.
  final List<ExerciseModel> availableExercises;

  @override
  State<CustomRoutineBuilderScreen> createState() =>
      _CustomRoutineBuilderScreenState();
}

/// One exercise planned inside the draft with its prescription.
class _DraftItem {
  _DraftItem(this.exercise);

  final ExerciseModel exercise;
  int sets = 3;
  int reps = 10;
  int restSeconds = 60;

  String get idKey => '${exercise.id}';
}

class _CustomRoutineBuilderScreenState
    extends State<CustomRoutineBuilderScreen> {
  late final TextEditingController _nameController;
  final List<_DraftItem> _selected = [];
  List<ExerciseModel> _catalog = const [];
  bool _loadingCatalog = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Mi rutina');
    _selected.add(_DraftItem(widget.initialExercise));
    _catalog = widget.availableExercises;
    _loadingCatalog = widget.availableExercises.isEmpty;
    if (widget.availableExercises.isEmpty) _loadCatalog();
  }

  /// The whole catalog so the user can mix any exercises, loaded from cache
  /// and refreshed from the network best-effort.
  Future<void> _loadCatalog() async {
    final cached = await ExerciseService().getCached();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _catalog = cached;
        _loadingCatalog = false;
      });
    }
    try {
      final fresh = await ExerciseService().fetchAndCache();
      if (mounted) {
        setState(() {
          _catalog = fresh;
          _loadingCatalog = false;
        });
      }
    } catch (_) {
      // The sheet simply shows fewer choices while offline.
    }
  }

  void _addExercise(ExerciseModel exercise) {
    if (_selected.any((item) => item.idKey == '${exercise.id}')) return;
    setState(() => _selected.add(_DraftItem(exercise)));
  }

  Future<void> _chooseExercise() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: _loadingCatalog && _catalog.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
              )
            : ListView(
                shrinkWrap: true,
                children: _catalog.map((exercise) {
                  final added =
                      _selected.any((item) => item.idKey == '${exercise.id}');
                  return ListTile(
                    enabled: !added,
                    leading: Icon(
                      added ? Icons.check : Icons.add_circle_outline,
                      color: added ? AppColors.subtext : AppColors.blue,
                    ),
                    title: Text(exercise.name,
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(exercise.category,
                        style: const TextStyle(fontSize: 11.5)),
                    onTap: !added
                        ? () {
                            _addExercise(exercise);
                            Navigator.pop(context);
                          }
                        : null,
                  );
                }).toList(),
              ),
      ),
    );
  }

  void _save() {
    final title = _nameController.text.trim();
    if (title.isEmpty || _selected.isEmpty) return;
    Navigator.pop(
      context,
      CustomRoutineDraft(
        title: title,
        exercises: _selected
            // Position comes from the declaration order the backend assigns.
            .map((item) => <String, dynamic>{
                  'exerciseId': int.tryParse(item.idKey),
                  'sets': item.sets.clamp(1, 20),
                  'reps': item.reps == 0 ? null : item.reps,
                  'restSeconds': item.restSeconds.clamp(0, 600),
                })
            .toList(),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
            'Elige varios ejercicios, ajusta tus series y guarda todo junto.',
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
                (entry) => _DraftTile(
                  index: entry.key + 1,
                  item: entry.value,
                  onChanged: () => setState(() {}),
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

/// Selected exercise row: preview image, name and sets/reps steppers.
class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.index,
    required this.item,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final _DraftItem item;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final image = absoluteUrl(item.exercise.gifUrl ?? item.exercise.imageUrl);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: image != null
                    ? Image.network(
                        image,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$index. ${item.exercise.name}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (onRemove != null)
                IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.repeat, size: 16, color: AppColors.subtext),
              const SizedBox(width: 4),
              Text('Series', style: const TextStyle(fontSize: 12, color: AppColors.subtext)),
              _stepper(
                '${item.sets}',
                onMinus: () => onChanged(),
                onPlus: () => onChanged(),
                minus: () => item.sets = (item.sets - 1).clamp(1, 20),
                plus: () => item.sets = (item.sets + 1).clamp(1, 20),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.fitness_center, size: 16, color: AppColors.subtext),
              const SizedBox(width: 4),
              const Text('Reps',
                  style: TextStyle(fontSize: 12, color: AppColors.subtext)),
              _stepper(
                '${item.reps}',
                minus: () => item.reps = (item.reps - 1).clamp(0, 100),
                plus: () => item.reps = (item.reps + 1).clamp(0, 100),
                onMinus: onChanged,
                onPlus: onChanged,
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 54,
        height: 54,
        color: AppColors.surface,
        child: const Icon(Icons.fitness_center, color: AppColors.blue, size: 22),
      );

  Widget _stepper(
    String value, {
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required void Function() minus,
    required void Function() plus,
  }) {
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 18),
          color: AppColors.subtext,
          onPressed: () {
            minus();
            onMinus();
          },
        ),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          color: AppColors.blue,
          onPressed: () {
            plus();
            onPlus();
          },
        ),
      ],
    );
  }
}

/// Detail of a persisted custom routine: cache-first detail load from
/// `/api/user-routines/{id}`, with delete for the owner and direct runner start.
class CustomRoutineDetailScreen extends StatefulWidget {
  const CustomRoutineDetailScreen({
    super.key,
    required this.routine,
    this.onDelete,
  });

  final CustomRoutineModel routine;
  final Future<void> Function()? onDelete;

  @override
  State<CustomRoutineDetailScreen> createState() =>
      _CustomRoutineDetailScreenState();
}

class _CustomRoutineDetailScreenState extends State<CustomRoutineDetailScreen> {
  final _customService = CustomRoutineService();
  RoutineDetailModel? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.routine.id;
    try {
      final detail = await _customService.detail(id);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return FrameScaffold(
      title: detail?.title ?? widget.routine.title,
      actions: [
        if (widget.onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.subtext),
            tooltip: 'Eliminar rutina',
            onPressed: _confirmDelete,
          ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : detail == null
              ? _errorView()
              : _content(detail),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No se pudo cargar la rutina.',
              style: TextStyle(color: AppColors.subtext)),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blue,
              side: const BorderSide(color: AppColors.blue),
            ),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _content(RoutineDetailModel detail) {
    return Column(
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
        Text(
          '${detail.exercises.length} ejercicios · rutina de tu catálogo',
          style: const TextStyle(color: AppColors.subtext),
        ),
        const SizedBox(height: 20),
        ...detail.exercises.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${e.position}. ${e.name} — ${e.prescriptionLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('descanso ${e.restLabel}',
                    style:
                        const TextStyle(fontSize: 11.5, color: AppColors.subtext)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WorkoutRunnerScreen(detail: detail),
              ),
            ),
            child: const Text(
              'Comenzar rutina',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar rutina'),
            content: Text(
                '¿Eliminar "${widget.routine.title}"? Tu historial de sesiones no se pierde.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await widget.onDelete?.call();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo eliminar la rutina.')));
      }
    }
  }
}

/// Carousel card for a persisted custom routine summary.
class CustomRoutineCard extends StatelessWidget {
  const CustomRoutineCard({
    super.key,
    required this.routine,
    required this.onTap,
  });

  final CustomRoutineModel routine;
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
            routine.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          Text(
            routine.meta,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
