import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_academy/screens/auth/welcome_screen.dart';
import 'package:aura_academy/screens/dashboard/dashboard_screen.dart';
import 'package:aura_academy/screens/courses/category_selection_screen.dart';
import 'supabase_config.dart';

// Controlador global para el tema
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Aura Academy',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // TEMA CLARO (Premium)
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Montserrat',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFFAFBFF),
          ),
          // TEMA OSCURO (Premium)
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Montserrat',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.dark,
              surface: const Color(0xFF0F172A),
            ),
            scaffoldBackgroundColor: const Color(0xFF020617),
          ),
          home: StreamBuilder<AuthState>(
            stream: Supabase.instance.client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final session = snapshot.hasData ? snapshot.data!.session : null;

              if (session != null) {
                return const DashboardScreen();
              } else {
                return const WelcomeScreen(key: ValueKey('welcome_screen'));
              }
            },
          ),
        );
      },
    );
  }
}






