import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/achievement_tile.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/section_label.dart';
import '../../achievements/models/achievement_model.dart';
import '../../achievements/services/achievement_service.dart';
import '../../stats/models/stats_model.dart';
import '../../stats/services/stats_service.dart';

const int _nextMilestone = 50;

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _achievementService = AchievementService();
  final _statsService = StatsService();
  List<AchievementModel> _unlocked = const [];
  UserStats? _stats;
  bool _failed = false;
  bool _isOfflineFallback = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 1. Immediately renders cached achievements & stats.
  /// 2. Fetches latest in background.
  Future<void> _loadData({bool isPullToRefresh = false}) async {
    final cachedAchievements = await _achievementService.getCached();
    final cachedStats = await _statsService.getCached();
    if (mounted && (cachedAchievements.isNotEmpty || cachedStats != null)) {
      setState(() {
        if (cachedAchievements.isNotEmpty) _unlocked = cachedAchievements;
        if (cachedStats != null) _stats = cachedStats;
      });
    }

    try {
      final results = await Future.wait([
        _achievementService.fetchAndCache(),
        _statsService.fetchAndCache(),
      ]);
      if (mounted) {
        setState(() {
          _unlocked = results[0] as List<AchievementModel>;
          _stats = results[1] as UserStats;
          _failed = false;
          _isOfflineFallback = false;
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          if (_unlocked.isEmpty && _stats == null) {
            _failed = true;
          } else {
            _isOfflineFallback = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_unlocked.isEmpty && _stats == null) {
            _failed = true;
          } else {
            _isOfflineFallback = true;
          }
        });
      }
    }
  }

  IconData _iconFor(String code) {
    switch (code) {
      case 'FIRST_WORKOUT':
        return Icons.flag_outlined;
      case 'FIRE_WEEK':
        return Icons.local_fire_department;
      case '100_WORKOUTS':
        return Icons.fitness_center;
      default:
        return Icons.military_tech_outlined;
    }
  }

  List<AchievementTile> _buildTiles() {
    final tiles = <AchievementTile>[];
    for (final achievement in _unlocked) {
      tiles.add(AchievementTile(
        icon: _iconFor(achievement.code),
        title: achievement.title.toUpperCase(),
        detail: achievement.description,
        unlocked: true,
      ));
    }

    const lockedIdeas = <(IconData, String, String)>[
      (Icons.bolt, 'MUSCLE-UP', 'Desbloquea un muscle-up'),
      (Icons.fitness_center, 'CENTURIÓN', '100 sesiones'),
      (Icons.people_outline, 'INSPIRADOR', 'Comparte 10 logros'),
      (Icons.timer_outlined, 'CONSTANTE', 'Entrena 7 días seguidos'),
      (Icons.terrain_outlined, 'PICO MÁXIMO', 'Registra tu mayor FC'),
      (Icons.thumb_up_off_alt_outlined, 'RECONOCIDO', 'Recibe 50 me gusta'),
    ];
    while (tiles.length < lockedIdeas.length) {
      final idea = lockedIdeas[tiles.length];
      tiles.add(AchievementTile(
        icon: idea.$1,
        title: idea.$2,
        detail: idea.$3,
        unlocked: false,
      ));
    }
    return tiles.sublist(0, lockedIdeas.length);
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _unlocked.length;
    final workouts = _stats?.totalWorkouts ?? 0;
    final progress = (workouts / _nextMilestone).clamp(0.0, 1.0);
    final tiles = _buildTiles();
    final rows = <List<AchievementTile>>[];
    for (var i = 0; i < tiles.length; i += 3) {
      rows.add(tiles.sublist(i, (i + 3).clamp(0, tiles.length)));
    }

    return FrameScaffold(
      title: 'Logros',
      onRefresh: () => _loadData(isPullToRefresh: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfflineBanner(isOfflineFallback: _isOfflineFallback),
          const SectionLabel('TU PROGRESO'),
          const SizedBox(height: 8),
          const Text(
            'Logros',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cada entrenamiento cuenta. Cada meta deja huella.',
            style: TextStyle(color: AppColors.subtext),
          ),
          const SizedBox(height: 22),
          // Level card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$unlockedCount',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOGROS DESBLOQUEADOS',
                        style: TextStyle(color: AppColors.subtext, fontSize: 9),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stats == null
                            ? 'SIN DATOS DE SESIONES'
                            : 'SESIONES REGISTRADAS: $workouts',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.progressBarBg,
                        color: AppColors.blue,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$workouts de $_nextMilestone sesiones al próximo hito',
                        style: const TextStyle(color: AppColors.subtext, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Text(
                'INSIGNIAS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '$unlockedCount LOGROS REALES',
                style: const TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: i < row.length
                          ? row[i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_failed && _unlocked.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'No se pudieron cargar los logros del servidor.',
              style: TextStyle(color: AppColors.subtext),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue,
                side: const BorderSide(color: AppColors.blue),
              ),
              onPressed: () => _loadData(),
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}
