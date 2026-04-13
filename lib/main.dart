import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/welcome_screen.dart';
import 'screens/dashboard_screen.dart';
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
        fontFamily: 'Montserrat',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.light,
        ),
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // Registro de depuración para ver qué pasa en tiempo real
          if (snapshot.hasData) {
            final event = snapshot.data!.event;
            final session = snapshot.data!.session;
            debugPrint("AUTH_EVENT: $event | SESSION_ACTIVE: ${session != null}");
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final session = snapshot.hasData ? snapshot.data!.session : null;

          if (session != null) {
            // Si hay sesión, vamos al Dashboard de cabeza
            return const DashboardScreen();
          } else {
            // Si no hay sesión, mostramos la bienvenida
            // Usamos un Key único para asegurar que la pantalla se limpie correctamente
            return const WelcomeScreen(key: ValueKey('welcome_screen'));
          }
        },
      ),
    );
  }
}

