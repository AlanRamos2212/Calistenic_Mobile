import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../shared/widgets/training_card.dart';
import '../../auth/services/auth_service.dart';
import '../../stats/models/stats_model.dart';
import '../../stats/services/stats_service.dart';
import '../services/streak_service.dart';

/// Home screen. The system home-screen widget (Android) shows the streak;
/// inside the app this screen stays clean with real stats only.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _statsService = StatsService();
  final _streakService = StreakService();
  String _userName = 'Alex';
  UserStats? _stats;
  int _streak = 0;
  bool _statsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadStats();
    _loadStreak();
  }

  Future<void> _loadUserName() async {
    final name = await _authService.getUserName();
    if (name != null && name.trim().isNotEmpty && mounted) {
      setState(() {
        _userName = name.trim().split(' ').first;
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _statsService.fetch();
      if (mounted) setState(() => _stats = stats);
    } on ApiException {
      if (mounted) setState(() => _statsFailed = true);
    } catch (e) {
      if (mounted) setState(() => _statsFailed = true);
    }
  }

  /// Computes the streak from real backend sessions and pushes it to the
  /// Android home screen widget. Failures keep the last saved value.
  Future<void> _loadStreak() async {
    final streak = await _streakService.refreshFromBackend();
    if (mounted) setState(() => _streak = streak);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('HOY EN TU PROGRESO'),
          const SizedBox(height: 8),
          Text(
            'Vamos a por ello, $_userName.',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          // Clean motivational block (the streak now lives in the system
          // home-screen widget, not inside the app).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fitness_center,
                  color: AppColors.blue,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¿Listo para entrenar hoy?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tu racha vive en el widget de inicio.',
                        style:
                            TextStyle(color: AppColors.subtext, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionLabel('PLAN DE HOY'),
          const SizedBox(height: 12),
          const TrainingCard(
            title: 'DOMINA TU PESO',
            subtitle: 'Fuerza de tirón',
            meta: '04 EJERCICIOS  ·  28 MIN  ·  DEMO',
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
              Expanded(
                child: MetricCard(value: '$_streak', label: 'RACHA'),
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
          if (_statsFailed) ...[
            const SizedBox(height: 12),
            Text(
              'No se pudieron cargar tus estadísticas reales.',
              style: TextStyle(color: AppColors.subtext, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
