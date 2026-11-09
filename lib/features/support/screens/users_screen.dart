import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/frame_scaffold.dart';
import '../services/support_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _service = SupportService();
  List<AppUser> _users = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await _service.users();
      if (mounted) setState(() => _users = list);
    } catch (_) {
      // best effort
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrameScaffold(
      title: 'Usuarios registrados',
      onRefresh: _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: Text('Lista de usuarios registrados en la app (solo ADMIN).'),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_users.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No hay usuarios registrados.'),
            ),
          for (final u in _users)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.blue.withValues(alpha: 0.15),
                  backgroundImage: u.avatarUrl != null && u.avatarUrl!.isNotEmpty
                      ? NetworkImage(u.avatarUrl!)
                      : null,
                  child: u.avatarUrl == null || u.avatarUrl!.isEmpty
                      ? Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AppColors.blue, fontWeight: FontWeight.bold))
                      : null,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        u.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (u.role == 'ADMIN')
                      const Chip(
                        label: Text('ADMIN',
                            style: TextStyle(fontSize: 8, color: Colors.white)),
                        backgroundColor: Colors.amber,
                        padding: EdgeInsets.symmetric(horizontal: 4),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.email, style: const TextStyle(fontSize: 12)),
                    if (u.createdAt != null)
                      Text('Registrado: ${u.createdAt}',
                          style: const TextStyle(fontSize: 10,
                              color: AppColors.subtext)),
                  ],
                ),
                trailing: u.role == 'ADMIN'
                    ? const Icon(Icons.admin_panel_settings,
                        color: Colors.amber, size: 20)
                    : const Icon(Icons.person, color: AppColors.subtext, size: 20),
                onTap: () {},
              ),
            ),
        ],
      ),
    );
  }
}
