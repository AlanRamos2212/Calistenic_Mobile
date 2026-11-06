import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../shared/widgets/training_card.dart';
import '../../exercises/models/exercise_model.dart';
import '../../exercises/services/exercise_service.dart';
import '../../exercises/screens/exercise_detail_screen.dart';
import '../models/routine_summary_model.dart';
import '../services/routine_service.dart';
import 'routine_detail_screen.dart';

/// Shows curated routines (`GET /api/routines`) plus the exercise catalog
/// from `GET /api/exercises`, both with Offline-First support.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final _exerciseService = ExerciseService();
  final _routineService = RoutineService();
  String _selectedCategory = 'Todas';
  List<ExerciseModel> _exercises = const [];
  List<RoutineSummaryModel> _routines = const [];
  bool _loading = false;
  bool _failed = false;
  bool _isOfflineFallback = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _loadRoutines();
  }

  /// Cached-first routines, then a fresh copy from the network.
  Future<void> _loadRoutines() async {
    try {
      final routines = await _routineService.list();
      if (mounted) setState(() => _routines = routines);
    } catch (_) {
      // Routine cards are a bonus; the catalog still loads without them.
    }
  }

  void _openRoutine(RoutineSummaryModel routine) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineDetailScreen(routine: routine),
      ),
    );
  }

  /// 1. Immediately renders cached exercises (0 delay).
  /// 2. Fetches latest catalog in background.
  Future<void> _loadExercises({bool isPullToRefresh = false}) async {
    final cached = await _exerciseService.getCached();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _exercises = cached;
        _loading = false;
      });
    } else if (!isPullToRefresh) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }

    try {
      final list = await _exerciseService.fetchAndCache();
      if (mounted) {
        setState(() {
          _exercises = list;
          _loading = false;
          _failed = false;
          _isOfflineFallback = false;
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_exercises.isEmpty) {
            _failed = true;
          } else {
            _isOfflineFallback = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_exercises.isEmpty) {
            _failed = true;
          } else {
            _isOfflineFallback = true;
          }
        });
      }
    }
  }

  List<String> get _allCategories {
    final names = [
      'Todas',
      ..._exercises.map((e) => e.category).toSet().toList()..sort(),
    ];
    return names;
  }

  List<ExerciseModel> get _filtered => _selectedCategory == 'Todas'
      ? _exercises
      : _exercises.where((e) => e.category == _selectedCategory).toList();

  String _metaFor(ExerciseModel e) {
    final metaParts = <String>[];
    if (e.level.isNotEmpty) metaParts.add(e.level.toUpperCase());
    if (e.durationMin != null && e.durationMin! > 0) {
      metaParts.add('${e.durationMin} MIN');
    }
    if (e.muscles.isNotEmpty) {
      metaParts.add(e.muscles.take(2).join(' · ').toUpperCase());
    }
    return metaParts.isEmpty ? 'GENERAL' : metaParts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final categories = _allCategories;
    final filtered = _filtered;

    return FrameScaffold(
      title: 'Rutinas',
      onRefresh: () =>
          Future.wait([_loadExercises(isPullToRefresh: true), _loadRoutines()]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfflineBanner(isOfflineFallback: _isOfflineFallback),
          const SectionLabel('ENTRENA A TU MANERA'),
          const SizedBox(height: 8),
          const Text(
            'Tus rutinas',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          // Curated routines carousel — tap a card to see its detail and train.
          if (_routines.isNotEmpty)
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 6),
                itemCount: _routines.length,
                separatorBuilder: (BuildContext _, int _) =>
                    const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final routine = _routines[i];
                  return _RoutineCard(
                    routine: routine,
                    onTap: () => _openRoutine(routine),
                  );
                },
              ),
            ),
          if (_routines.isNotEmpty) const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: AppColors.blue,
                backgroundColor: AppColors.card,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.subtext,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCategory = cat);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (_loading && _exercises.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.blue),
              ),
            )
          else if (_failed && _exercises.isEmpty)
            Column(
              children: [
                const Text(
                  'No se pudieron cargar los ejercicios del servidor.',
                  style: TextStyle(color: AppColors.subtext),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blue,
                    side: const BorderSide(color: AppColors.blue),
                  ),
                  onPressed: () => _loadExercises(),
                  child: const Text('Reintentar'),
                ),
              ],
            )
          else if (filtered.isEmpty)
            const Text(
              'Todavía no hay ejercicios en esta categoría.',
              style: TextStyle(color: AppColors.subtext),
            )
          else
            ...filtered.map(
              (exercise) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TrainingCard(
                  title: exercise.name.toUpperCase(),
                  subtitle: exercise.category,
                  meta: _metaFor(exercise),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExerciseDetailScreen(exercise: exercise),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact horizontal card for a routine summary, styled like TrainingCard.
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.onTap});

  final RoutineSummaryModel routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              routine.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                routine.subtitle.isEmpty ? routine.meta : routine.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.subtext,
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              routine.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
