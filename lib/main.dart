import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/providers/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: StatTracApp()));
}

class StatTracApp extends StatelessWidget {
  const StatTracApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stat Trac Technical',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const _AuthGate(),
      routes: {
        '/dashboard': (_) => const DashboardScreen(),
      },
    );
  }
}

/// Routes to LoginScreen or DashboardScreen based on stored auth state.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return switch (authState) {
      AuthAuthenticated() => const DashboardScreen(),
      _ => const LoginScreen(),
    };
  }
}
