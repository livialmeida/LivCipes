import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app_theme.dart';
import 'features/auth/access_gate_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const LivCipesApp());
}

class LivCipesApp extends StatelessWidget {
  const LivCipesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LivCipes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AccessGateScreen(),
    );
  }
}