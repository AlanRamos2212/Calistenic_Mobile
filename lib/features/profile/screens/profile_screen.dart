import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../stats/models/stats_model.dart';
import '../../stats/services/stats_service.dart';
import '../models/user_profile_model.dart';
import '../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _statsService = StatsService();
  final _authService = AuthService();
  final _picker = ImagePicker();

  UserProfileModel? _profile;
  UserStats? _stats;
  File? _localAvatarFile;
  bool _signingOut = false;
  bool _loadingAvatar = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    // 1) Render from cache immediately (works offline)
    final cachedProfile = await _profileService.getCached();
    final cachedStats = await _statsService.getCached();
    if (mounted) {
      setState(() {
        if (cachedProfile != null) _profile = cachedProfile;
        if (cachedStats != null) _stats = cachedStats;
      });
    }

    // 2) Refresh from network in background
    await Future.wait([_refreshProfile(), _refreshStats()]);
  }

  Future<void> _refreshProfile() async {
    try {
      final fresh = await _profileService.fetchAndCache();
      if (mounted) {
        setState(() {
          _profile = fresh;
          _isOffline = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _forceLogout();
        return;
      }
      if (e.statusCode == null && mounted) {
        setState(() => _isOffline = true);
      }
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  Future<void> _refreshStats() async {
    try {
      final fresh = await _statsService.fetchAndCache();
      if (mounted) setState(() => _stats = fresh);
    } catch (_) {
      // Keep cached stats; offline banner already shown via _refreshProfile
    }
  }

  // ── Edit name ─────────────────────────────────────────────────────────────

  Future<void> _editName() async {
    final controller =
        TextEditingController(text: _profile?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Editar nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Tu nombre completo',
            counterStyle: TextStyle(color: AppColors.subtext),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.subtext)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    final newName = result?.trim() ?? '';
    if (newName.isEmpty || newName == _profile?.name || !mounted) return;

    try {
      final updated = await _profileService.updateName(newName);
      if (mounted) setState(() => _profile = updated);
      _showSnack('Nombre actualizado ✓');
    } on ApiException catch (e) {
      _showSnack(e.message, error: true);
    }
  }

  // ── Upload avatar ─────────────────────────────────────────────────────────

  Future<void> _pickAndUploadAvatar() async {
    // Let user choose source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.subtext,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.blue),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.blue),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final imageFile = File(picked.path);
    // Optimistically show the chosen local image immediately
    setState(() {
      _localAvatarFile = imageFile;
      _loadingAvatar = true;
    });

    try {
      final avatarUrl = await _profileService.uploadAvatar(imageFile);
      if (mounted) {
        setState(() {
          _profile = _profile?.copyWith(avatarUrl: avatarUrl);
          _localAvatarFile = null;
        });
        _showSnack('Foto actualizada ✓');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _localAvatarFile = null);
        _showSnack(e.message, error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localAvatarFile = null);
        _showSnack('No se pudo subir la foto: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _loadingAvatar = false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('Cerrar sesión'),
            content: const Text(
                '¿Quieres cerrar tu sesión en este dispositivo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppColors.subtext)),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;
    setState(() => _signingOut = true);
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _forceLogout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : AppColors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _initials {
    final name = _profile?.name ?? '';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '';
  }

  String get _roleLabel {
    switch ((_profile?.role ?? '').toUpperCase()) {
      case 'ADMIN':
        return 'Administrador';
      default:
        return 'Atleta';
    }
  }

  String? get _memberSince {
    final raw = _profile?.createdAt;
    if (raw == null) return null;
    try {
      final dt = DateTime.parse(raw);
      final months = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
      ];
      return 'Miembro desde ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return null;
    }
  }

  String? get _fullAvatarUrl {
    final rel = _profile?.avatarUrl;
    if (rel == null || rel.isEmpty) return null;
    if (rel.startsWith('http://') || rel.startsWith('https://')) return rel;
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (rel.startsWith('/api/')) return '$base$rel';
    if (rel.startsWith('/')) return '$base$rel';
    return '$base/api/media/$rel';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FrameScaffold(
      title: 'Perfil',
      onRefresh: _loadAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_isOffline) const OfflineBanner(),
          const SizedBox(height: 20),

          // ── Avatar ──────────────────────────────────────────────────────
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              _buildAvatar(),
              GestureDetector(
                onTap: _loadingAvatar ? null : _pickAndUploadAvatar,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                  child: _loadingAvatar
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Name + edit button ───────────────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _profile?.name.toUpperCase() ?? '—',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _editName,
                child: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.blue),
              ),
            ],
          ),

          if ((_profile?.email ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_profile!.email,
                style: const TextStyle(color: AppColors.subtext, fontSize: 13)),
          ],

          const SizedBox(height: 6),

          // ── Role badge ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.4)),
            ),
            child: Text(
              _roleLabel,
              style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),

          if (_memberSince != null) ...[
            const SizedBox(height: 6),
            Text(_memberSince!,
                style: const TextStyle(color: AppColors.subtext, fontSize: 12)),
          ],

          const SizedBox(height: 24),

          // ── Stats row ────────────────────────────────────────────────────
          _buildStatsRow(),

          const SizedBox(height: 24),

          // ── Settings tiles ───────────────────────────────────────────────
          _buildTile(
            icon: Icons.watch_outlined,
            title: 'Wearable',
            subtitle: 'Sincronización · Próximamente',
            trailing: Icons.help_outline,
            color: AppColors.blue,
          ),
          _buildTile(
            icon: Icons.settings_outlined,
            title: 'Preferencias',
            trailing: Icons.chevron_right,
            color: AppColors.subtext,
          ),

          const SizedBox(height: 24),

          // ── Logout ───────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _signingOut ? null : _logout,
              icon: _signingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.redAccent),
                    )
                  : const Icon(Icons.logout),
              label: Text(
                _signingOut ? 'Cerrando sesión...' : 'Cerrar sesión',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildAvatar() {
    if (_localAvatarFile != null) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: AppColors.blue,
        backgroundImage: FileImage(_localAvatarFile!),
      );
    }

    final url = _fullAvatarUrl;
    return GestureDetector(
      onTap: _loadingAvatar ? null : _pickAndUploadAvatar,
      child: CircleAvatar(
        radius: 50,
        backgroundColor: AppColors.blue,
        child: url != null
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                  errorWidget: (context, url, error) => _initialsText(),
                ),
              )
            : _initialsText(),
      ),
    );
  }

  Widget _initialsText() => Text(
        _initials,
        style: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
      );

  Widget _buildStatsRow() {
    final sessions = _stats?.totalWorkouts ?? 0;
    final minutes = _stats?.totalMinutes ?? 0;
    final bpm = _stats?.avgBpm ?? 0;

    return Row(
      children: [
        _StatCard(value: '$sessions', label: 'SESIONES'),
        const SizedBox(width: 8),
        _StatCard(value: '${minutes}m', label: 'TIEMPO'),
        const SizedBox(width: 8),
        _StatCard(value: '$bpm', label: 'BPM PROM.'),
      ],
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required IconData trailing,
    required Color color,
  }) =>
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(color: AppColors.subtext))
            : null,
        trailing: Icon(trailing, color: AppColors.subtext),
      );
}

// ── _StatCard ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.subtext,
                  letterSpacing: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}
