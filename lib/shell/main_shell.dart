import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../features/achievements/screens/achievements_screen.dart';
import '../../../features/home/screens/home_screen.dart';
import '../../../features/profile/screens/profile_screen.dart';
import '../../../features/routines/screens/routines_screen.dart';
import '../../../features/social/screens/social_screen.dart';
import '../../../features/support/screens/support_screen.dart';
import '../../../features/support/screens/users_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _auth = AuthService();
  int _selectedIndex = 0;
  bool _isAdmin = false;
  bool _loadingRole = true;

  // Páginas para usuario normal (USER)
  final List<Widget> _pagesUser = const [
    HomeScreen(),
    RoutinesScreen(),
    SocialScreen(),
    AchievementsScreen(),
    ProfileScreen(),
  ];

  // Páginas para admin: solo lo esencial del soporte
  final List<Widget> _pagesAdmin = const [
    ProfileScreen(),
    SupportScreen(),
    UsersScreen(),
  ];

  // Destinos para usuario normal
  final List<NavigationDestination> _destUser = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Inicio',
    ),
    NavigationDestination(
      icon: Icon(Icons.fitness_center_outlined),
      selectedIcon: Icon(Icons.fitness_center),
      label: 'Rutinas',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Social',
    ),
    NavigationDestination(
      icon: Icon(Icons.emoji_events_outlined),
      selectedIcon: Icon(Icons.emoji_events),
      label: 'Logros',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Perfil',
    ),
  ];

  // Destinos para admin: solo lo relevante
  final List<NavigationDestination> _destAdmin = const [
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Perfil',
    ),
    NavigationDestination(
      icon: Icon(Icons.help_outline),
      selectedIcon: Icon(Icons.help),
      label: 'Soporte',
    ),
    NavigationDestination(
      icon: Icon(Icons.admin_panel_settings),
      selectedIcon: Icon(Icons.admin_panel_settings),
      label: 'Usuarios',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final role = await _auth.getUserRole();
      if (mounted) setState(() => _isAdmin = role == 'ADMIN');
    } catch (_) {
      // best effort
    } finally {
      if (mounted) setState(() => _loadingRole = false);
    }
  }

  List<Widget> get _pages => _isAdmin ? _pagesAdmin : _pagesUser;
  List<NavigationDestination> get _destinations =>
      _isAdmin ? _destAdmin : _destUser;

  @override
  Widget build(BuildContext context) {
    if (_loadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: _destinations,
      ),
    );
  }
}
