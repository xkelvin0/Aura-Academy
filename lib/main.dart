import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Montserrat', // Fuente por defecto (puedes cambiarla en pubspec.yaml)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.light,
        ),
      ),
      home: const WelcomeScreen(), // Iniciamos con la pantalla de bienvenida
    );
  }
}
