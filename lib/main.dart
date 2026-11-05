import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'shell/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  final hasSession = await authService.isAuthenticated();

  runApp(App(initialHasSession: hasSession));
}

/// Root widget of the CalisthenicTrack application.
class App extends StatelessWidget {
  final bool initialHasSession;

  const App({
    super.key,
    this.initialHasSession = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CalisthenicTrack',
      theme: AppTheme.darkTheme,
      home: initialHasSession ? const MainShell() : const LoginScreen(),
    );
  }
}
