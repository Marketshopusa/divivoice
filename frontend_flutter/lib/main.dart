import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiviVoice - StarMaker Karaoke',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: ApiService.isAuthenticated ? const HomeScreen() : const HomeScreen(), // Permitir entrar directo para demo
    );
  }
}
