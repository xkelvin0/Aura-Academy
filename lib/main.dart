import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/welcome_screen.dart';
import 'supabase_config.dart';

// Función principal - inicializa Supabase antes de lanzar la app
Future<void> main() async {
  // Necesario para usar código asíncrono antes de runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializamos la conexión con Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

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
