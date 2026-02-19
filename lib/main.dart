import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_app_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HeartStrokeApp());
}

class HeartStrokeApp extends StatelessWidget {
  const HeartStrokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heart Stroke Prediction',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const _RootDecider(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _RootDecider extends StatefulWidget {
  const _RootDecider();

  @override
  State<_RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<_RootDecider> {
  @override
  void initState() {
    super.initState();
    // Resolve after first frame to render UI immediately and avoid
    // recreating the async future on rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final next = await _decideStartScreen();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    });
  }

  Future<Widget> _decideStartScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('onboarded') ?? false;
    if (!onboarded) return const OnboardingScreen();

    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!loggedIn) return const LoginScreen();

    return const MainAppScreen();
  }

  @override
  Widget build(BuildContext context) {
    // Lightweight splash while routing decision resolves.
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
