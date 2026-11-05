import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/routine_detail_model.dart';
import '../services/workout_service.dart';

enum _RunnerPhase { workout, rest, summary }

/// Runs a routine: workout clock, per-set progression with a countdown rest
/// timer, and a wearable session per exercise opened after its first completed
/// set (so quitting early leaves no orphan sessions in the backend).
class WorkoutRunnerScreen extends StatefulWidget {
  const WorkoutRunnerScreen({super.key, required this.detail});

  final RoutineDetailModel detail;

  @override
  State<WorkoutRunnerScreen> createState() => _WorkoutRunnerScreenState();
}

/// Tracks the wearable session of the exercise currently being performed.
class _ActiveSession {
  _ActiveSession(this.exerciseId) : stopwatch = Stopwatch()..start();

  final int exerciseId;
  final Stopwatch stopwatch;
  int? sessionId;
  bool startInFlight = false;

  /// True when the exercise moved on before `startSession` answered:
  /// the session must be closed as soon as its id arrives.
  bool closedWithoutId = false;
}

class _WorkoutRunnerScreenState extends State<WorkoutRunnerScreen> {
  final _workoutService = WorkoutService();

  late final List<RoutineExerciseItem> _exercises = widget.detail.exercises;

  Timer? _uiTicker;
  Timer? _restTicker;
  final Stopwatch _workoutStopwatch = Stopwatch()..start();

  _RunnerPhase _phase = _RunnerPhase.workout;
  int _exerciseIndex = 0;
  int _setsDone = 0;
  int _restRemaining = 0;
  bool _paused = false;
  bool _ended = false;

  // Stats for the summary: total sets and estimated calories.
  final Map<int, int> _setsDoneByIndex = {};
  double _caloriesDone = 0;

  _ActiveSession? _session;

  // ---- Derived ---------------------------------------------------------

  RoutineExerciseItem get _current => _exercises[_exerciseIndex];

  bool get _isLastExercise => _exerciseIndex >= _exercises.length - 1;

  String _clockLabel() {
    final elapsed = _workoutStopwatch.elapsed;
    String two(int v) => v.toString().padLeft(2, '0');
    if (elapsed.inHours > 0) {
      return '${elapsed.inHours}:${two(elapsed.inMinutes % 60)}:${two(elapsed.inSeconds % 60)}';
    }
    return '${elapsed.inMinutes}:${two(elapsed.inSeconds % 60)}';
  }

  // ---- Lifecycle -------------------------------------------------------

  @override
  void initState() {
    super.initState();
    // Repaints the workout clock while running.
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_phase == _RunnerPhase.workout && !_paused) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _restTicker?.cancel();
    // Log the open (partial) session so nothing stays orphaned in the backend.
    _disposeSession();
    super.dispose();
  }

  // ---- Session handling --------------------------------------------------

  /// Opens the wearable session right after the first set of an exercise.
  void _ensureSessionStarted() {
    if (_session != null) return;
    final exerciseId = int.tryParse(_current.id);
    if (exerciseId == null) return;

    final session = _ActiveSession(exerciseId);
    _session = session;
    session.startInFlight = true;

    _workoutService.startSession(session.exerciseId).then((id) async {
      session.startInFlight = false;
      final durationSec = session.stopwatch.elapsed.inSeconds;
      final calories = _caloriesForExercise(exerciseId, false);
      if (session.closedWithoutId) {
        _stopQuietly(id, durationSec, calories);
        return;
      }
      if (mounted) setState(() => session.sessionId = id);
    }).catchError((e) {
      session.startInFlight = false;
    });
  }

  /// Closes the active session when the exercise is finished (last set done)
  /// or when the runner exits. Fire-and-forget; never blocks the UI.
  void _closeSessionOrUpdate({required bool ended}) {
    final session = _session;
    if (session == null) return;
    final durationSec = session.stopwatch.elapsed.inSeconds;
    final id = session.sessionId;

    if (session.startInFlight && id == null) {
      // Let the start callback close it as soon as it resolves.
      session.closedWithoutId = true;
      _session = null;
      return;
    }

    _session = null;
    if (id == null) return;
    _stopQuietly(id, durationSec, _caloriesForExercise(session.exerciseId, ended));
  }

  void _stopQuietly(int sessionId, int durationSec, double calories) {
    _workoutService
        .stopSession(sessionId, durationSec: durationSec, caloriesBurned: calories)
        .catchError((e) {});
  }

  /// Estimated calories contributed by one exercise, proportional to the
  /// completed sets. Honest approximation — no HR/fake metrics involved.
  double _caloriesForExercise(int exerciseId, bool ended) {
    final index =
        _exercises.indexWhere((e) => int.tryParse(e.id) == exerciseId);
    if (index < 0) return 0;
    final item = _exercises[index];
    final estimated = item.estimatedCalories;
    if (estimated == null || estimated <= 0) return 0;
    final fraction = ended
        ? 1.0
        : (_setsDoneByIndex[index] ?? _setsDone) / item.sets;
    return estimated * fraction.clamp(0.0, 1.0);
  }

  void _disposeSession() {
    // On dispose we cannot setState; flush the pending session defensively.
    final session = _session;
    if (session == null) return;
    if (session.startInFlight) {
      session.closedWithoutId = true;
      return;
    }
    final id = session.sessionId;
    _session = null;
    if (id == null) return;
    _stopQuietly(
        id, session.stopwatch.elapsed.inSeconds,
        _caloriesForExercise(session.exerciseId, true));
  }

  // ---- Set flow -----------------------------------------------------------

  void _completeSet() {
    if (_ended || _phase == _RunnerPhase.rest || _phase == _RunnerPhase.summary) {
      return;
    }
    final item = _current;

    setState(() {
      _setsDone++;
      _setsDoneByIndex[_exerciseIndex] = _setsDone;
    });

    // Calories accumulate per completed set (equal share per series).
    final itemCal = item.estimatedCalories;
    if (itemCal != null && itemCal > 0) {
      setState(() => _caloriesDone += itemCal / item.sets);
    }

    _ensureSessionStarted();

    if (_setsDone >= item.sets) {
      // Last set of this exercise: leave the floor for the user to keep the
      // rhythm; the advance button takes over from here.
      _restTicker?.cancel();
      _restTicker = null;
      _restRemaining = 0;
      return;
    }
    if (item.restSeconds > 0) {
      _startRest(item.restSeconds);
    }
  }

  /// After the last set of an exercise: close its session and move on.
  Future<void> _advanceExercise() async {
    _closeSessionOrUpdate(ended: true);

    if (_isLastExercise) {
      _finishWorkout();
      return;
    }
    if (!mounted) return;
    setState(() {
      _exerciseIndex++;
      _setsDone = 0;
    });
    if (_current.restSeconds > 0) {
      // Transition break between exercises, comfortably longer by-less rule:
      // use the new exercise's rest seconds as its own pre-series rest.
      _startRest(_current.restSeconds);
    }
  }

  void _startRest(int seconds) {
    _restTicker?.cancel();
    setState(() {
      _phase = _RunnerPhase.rest;
      _restRemaining = seconds;
    });
    _restTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused) return;
      if (_restRemaining <= 1) {
        _restTicker?.cancel();
        _restTicker = null;
        if (!mounted) return;
        setState(() {
          _restRemaining = 0;
          _phase = _RunnerPhase.workout;
        });
        return;
      }
      setState(() => _restRemaining--);
    });
  }

  void _skipRest() {
    _restTicker?.cancel();
    _restTicker = null;
    setState(() {
      _restRemaining = 0;
      _phase = _RunnerPhase.workout;
    });
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _workoutStopwatch.stop();
      } else {
        _workoutStopwatch.start();
      }
    });
  }

  void _finishWorkout() {
    setState(() {
      _phase = _RunnerPhase.summary;
      _ended = true;
      _workoutStopwatch.stop();
    });
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _RunnerPhase.summary,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: _phase == _RunnerPhase.summary
              ? _summaryView()
              : _runView(),
        ),
      ),
    );
  }

  Future<void> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Abandonar entrenamiento',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            '¿Salir antes de terminar? El progreso de series y la sesión '
            'actual se registrarán hasta este punto.',
            style: TextStyle(color: AppColors.subtext)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir entrenando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir',
                style: TextStyle(color: AppColors.blue)),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      // Persist partial progress and leave without showing the summary.
      _restTicker?.cancel();
      _closeSessionOrUpdate(ended: false);
      setState(() => _ended = true);
      Navigator.pop(context);
    }
  }

  Widget _runView() {
    final setsTotal = _windowsTotal();
    final nextItem = !_isLastExercise ? _exercises[_exerciseIndex + 1] : null;
    return Column(
      children: [
        // Top status bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                color: AppColors.subtext,
                icon: const Icon(Icons.close),
                onPressed: _confirmExit,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('EJERCICIO ${_exerciseIndex + 1} DE ${_exercises.length}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.subtext,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                    Text(_current.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17)),
                  ],
                ),
              ),
              IconButton(
                color: _paused ? AppColors.blue : AppColors.subtext,
                icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                onPressed: _togglePause,
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _phase == _RunnerPhase.rest ? _restView(nextItem) : _workoutView(setsTotal),
            ),
          ),
        ),
        _bottomAction(setsTotal),
      ],
    );
  }

  int _windowsTotal() => _current.sets;

  Widget _workoutView(int setsTotal) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_clockLabel(),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 30,
                fontWeight: FontWeight.w300,
                fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 18),
        Text(
          _setsDone < setsTotal
              ? 'Serie ${_setsDone + 1} de $setsTotal'
              : 'Serie final',
          style: const TextStyle(
              color: AppColors.subtext,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: List.generate(setsTotal, (i) {
            final done = i < _setsDone;
            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.blue : AppColors.card,
                border: Border.all(
                    color: done ? AppColors.blue : AppColors.cardBorder),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Text(_prescriptionText(),
            style: const TextStyle(color: Colors.white, fontSize: 15)),
      ],
    );
  }

  String _prescriptionText() {
    final item = _current;
    return item.reps == null
        ? 'Mantén la posición (isométrico)'
        : '${item.reps} repeticiones por serie';
  }

  Widget _restView(RoutineExerciseItem? nextItem) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('DESCANSO',
            style: TextStyle(
                color: AppColors.subtext,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2)),
        const SizedBox(height: 8),
        Text('$_restRemaining',
            style: const TextStyle(
                color: AppColors.blue,
                fontSize: 72,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        if (nextItem != null) ...[
          Text('Siguiente: ${nextItem.name}',
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 2),
          Text(nextItem.reps == null
              ? '${nextItem.sets} series isométricas'
              : '${nextItem.sets} × ${nextItem.reps} repeticiones',
              style: const TextStyle(color: AppColors.subtext, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _bottomAction(int setsTotal) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_phase == _RunnerPhase.rest) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: AppColors.blue,
                  side: const BorderSide(color: AppColors.blue),
                ),
                onPressed: _skipRest,
                child: const Text('Saltar descanso',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
            ] else if (_paused) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _togglePause,
                  child: const Text('Reanudar',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.white)),
                ),
              ),
            ] else if (_setsDone >= setsTotal) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: _isLastExercise
                          ? const Color(0xFF1DB954)
                          : AppColors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _advanceExercise,
                  child: Text(
                      _isLastExercise ? 'Terminar rutina' : 'Siguiente ejercicio',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.white)),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _completeSet,
                  child: const Text('Completar serie',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryView() {
    final minutes = _workoutStopwatch.elapsed.inMinutes;
    final seconds = _workoutStopwatch.elapsed.inSeconds % 60;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFF1DB954), size: 64),
            const SizedBox(height: 12),
            const Text('¡Entrenamiento completado!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(widget.detail.title,
                style: const TextStyle(color: AppColors.subtext)),
            const SizedBox(height: 24),
            _summaryRow('Duración',
                '${minutes}m ${seconds}s'),
            _summaryRow('Series completadas',
                '${_setsDoneByIndex.values.fold(0, (a, b) => a + b)}'),
            _summaryRow('Calorías estimadas',
                '${_caloriesDone.round()} kcal'),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Hecho',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.subtext, fontSize: 13))),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
