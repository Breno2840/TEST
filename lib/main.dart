import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const RadioApp());
}

class RadioApp extends StatelessWidget {
  const RadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Player',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        primaryColor: const Color(0xFF6C63FF),
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}