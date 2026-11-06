import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../shared/widgets/training_card.dart';
import '../../exercises/models/exercise_model.dart';
import '../../exercises/services/exercise_service.dart';
import '../../exercises/screens/exercise_detail_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../stats/models/stats_model.dart';
import '../../stats/services/stats_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _statsService = StatsService();
  final _exerciseService = ExerciseService();
  ExerciseModel? _featuredExercise;
  String _userName = 'Alex';
  UserStats? _stats;
  bool _statsFailed = false;
  bool _isOfflineFallback = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadStats();
    _loadFeaturedExercise();
  }

  Future<void> _loadFeaturedExercise() async {
    final cached = await _exerciseService.getCached();
    if (cached.isNotEmpty && mounted) {
      setState(() => _featuredExercise = cached.first);
    }
    try {
      final exercises = await _exerciseService.fetchAndCache();
      if (mounted && exercises.isNotEmpty) {
        setState(() => _featuredExercise = exercises.first);
      }
    } catch (_) {
      // The home card remains visible even when the catalog is offline.
    }
  }

  Future<void> _loadUserName() async {
    final name = await _authService.getUserName();
    if (name != null && name.trim().isNotEmpty && mounted) {
      setState(() {
        _userName = name.trim().split(' ').first;
      });
    }
  }

  /// 1. Immediately renders cached stats.
  /// 2. Refreshes in background.
  Future<void> _loadStats({bool isPullToRefresh = false}) async {
    final cached = await _statsService.getCached();
    if (cached != null && mounted) {
      setState(() {
        _stats = cached;
      });
    }

    try {
      final stats = await _statsService.fetchAndCache();
      if (mounted) {
        setState(() {
          _stats = stats;
          _statsFailed = false;
          _isOfflineFallback = false;
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          if (_stats == null) {
            _statsFailed = true;
          } else {
            _isOfflineFallback = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_stats == null) {
            _statsFailed = true;
          } else {
            _isOfflineFallback = true;
          }
        });
      }
    }
  }

  /// Formats minutes as hours when there is at least one full hour.
  String _fmtTime(int minutes) {
    if (minutes >= 60) {
      final hours = minutes / 60;
      return hours.remainder(1) == 0
          ? '${hours.toStringAsFixed(0)}h'
          : '${hours.toStringAsFixed(1)}h';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return FrameScaffold(
      title: 'CalisthenicTrack',
      onRefresh: () => _loadStats(isPullToRefresh: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfflineBanner(isOfflineFallback: _isOfflineFallback),
          const SectionLabel('HOY EN TU PROGRESO'),
          const SizedBox(height: 8),
          Text(
            'Vamos a por ello, $_userName.',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          // Motivational hero banner shown when entering the app.
          const _MotivationBanner(),
          const SizedBox(height: 24),
          // Streak card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.cardBorder.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '12 DÍAS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'RACHA ACTUAL (DEMO)',
                      style: TextStyle(color: AppColors.subtext, fontSize: 10),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'MEJOR\n18',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.subtext,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionLabel('PLAN DE HOY'),
          const SizedBox(height: 12),
          TrainingCard(
            title: 'DOMINA TU PESO',
            subtitle: 'Fuerza de tirón',
            meta: '04 EJERCICIOS  ·  28 MIN  ·  DEMO',
            onTap: () {
              final exercise = _featuredExercise;
              if (exercise == null) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExerciseDetailScreen(exercise: exercise),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          const SectionLabel('TU ACTIVIDAD'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  value: _stats != null ? '${_stats!.totalWorkouts}' : '—',
                  label: 'SESIONES',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: MetricCard(value: '12', label: 'RACHA · DEMO'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  value: _stats != null ? _fmtTime(_stats!.totalMinutes) : '—',
                  label: 'TIEMPO',
                ),
              ),
            ],
          ),
          if (_statsFailed && _stats == null) ...[
            const SizedBox(height: 12),
            Text(
              'No se pudieron cargar tus estadísticas del servidor.',
              style: TextStyle(color: AppColors.subtext, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hero image bundled with the app ("Home_inicio"): sets the training mood
/// the moment the app opens, with a motivational caption over a gradient.
class _MotivationBanner extends StatelessWidget {
  const _MotivationBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 2.6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/home_inicio.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [Color(0xB307101B), Color(0x1407101B)],
                ),
              ),
            ),
            const Positioned(
              left: 14,
              bottom: 12,
              child: Text(
                'Cada rep te acerca a tu mejor versión.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  shadows: [Shadow(blurRadius: 8, color: Color(0xCC07101B))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
