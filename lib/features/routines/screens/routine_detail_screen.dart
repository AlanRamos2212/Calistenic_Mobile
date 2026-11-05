import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../models/routine_detail_model.dart';
import '../models/routine_summary_model.dart';
import '../services/routine_service.dart';
import 'workout_runner_screen.dart';

/// Detail of one routine: ordered exercises with sets, reps, rest seconds
/// and technique description. Starts the workout runner.
class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({super.key, required this.routine});

  final RoutineSummaryModel routine;

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  final _routineService = RoutineService();

  RoutineDetailModel? _detail;
  bool _loading = true;
  bool _failed = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Cached-first paint, then fresh copy from the network.
  Future<void> _load() async {
    final cached = await _routineService.getCachedDetail(widget.routine.id);
    if (cached != null && mounted) {
      setState(() {
        _detail = cached;
        _loading = false;
      });
    }

    try {
      final fresh = await _routineService.detail(widget.routine.id);
      if (mounted) {
        setState(() {
          _detail = fresh;
          _loading = false;
          _failed = false;
          _isOffline = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted && _detail == null) {
        setState(() {
          _loading = false;
          // Explicit server errors (401/404/503) are not offline fallbacks.
          _failed = true;
          _isOffline = e.statusCode == null;
        });
      }
    } catch (_) {
      if (mounted && _detail == null) {
        setState(() => _loading = false);
      }
    }
  }

  void _startWorkout() {
    final detail = _detail;
    if (detail == null || detail.exercises.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WorkoutRunnerScreen(detail: detail),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: Colors.white,
        title: Text(detail?.title ?? widget.routine.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _failed || detail == null
              ? _errorView()
              : _content(detail),
      bottomNavigationBar: detail == null ? null : _startBar(detail),
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
              setState(() {
                _loading = true;
                _failed = false;
              });
              _load();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _content(RoutineDetailModel detail) {
    return RefreshIndicator(
      color: AppColors.blue,
      backgroundColor: AppColors.card,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          OfflineBanner(isOfflineFallback: _isOffline),
          Text(detail.subtitle,
              style: const TextStyle(color: AppColors.subtext, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(detail.level.toUpperCase()),
              if (detail.durationMin != null) _chip('${detail.durationMin} MIN'),
              if (detail.estimatedCalories != null)
                _chip('~${detail.estimatedCalories} KCAL'),
              _chip('${detail.exercises.length} EJERCICIOS'),
            ],
          ),
          const SizedBox(height: 22),
          ...detail.exercises.map(_exerciseCard),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _exerciseCard(RoutineExerciseItem e) {
    final gif = e.gifUrl ?? e.imageUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: gif != null && gif.isNotEmpty
                    ? Image.network(
                        gif,
                        width: 74,
                        height: 74,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _gifPlaceholder(e.position),
                      )
                    : _gifPlaceholder(e.position),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.position}. ${e.name}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white),
                    ),
                    if (e.muscles != null) ...[
                      const SizedBox(height: 3),
                      Text(e.muscles!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.subtext)),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${e.prescriptionLabel} · descanso ${e.restLabel}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.blue,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (e.techniqueDescription != null &&
              e.techniqueDescription!.trim().isNotEmpty) ...[
            const Divider(height: 22, color: AppColors.cardBorder),
            const Text('TÉCNICA',
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.subtext,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(
              e.techniqueDescription!,
              style:
                  const TextStyle(fontSize: 12.5, height: 1.35, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gifPlaceholder(int position) {
    return Container(
      width: 74,
      height: 74,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Text('$position',
          style: const TextStyle(
              color: AppColors.subtext,
              fontWeight: FontWeight.w900,
              fontSize: 20)),
    );
  }

  Widget _startBar(RoutineDetailModel detail) {
    final busy = detail.exercises.isEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: busy ? AppColors.card : AppColors.blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: busy ? null : _startWorkout,
            child: const Text('Comenzar rutina',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
