import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'register_screen.dart'; // Importamos la pantalla de registro
import 'dashboard_screen.dart'; // Importamos el dashboard

// Pantalla de inicio de sesión de Aura Academy
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores para los campos de texto
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Controla si la contraseña es visible o no
  bool _passwordVisible = false;
  bool _isLoading = false; // Controla el estado de carga al iniciar sesión

  // Función para iniciar sesión con Google
  Future<void> _loginConGoogle() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.auraacademy://login-callback',
    );
  }

  // Función para iniciar sesión con GitHub
  Future<void> _loginConGitHub() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: 'io.supabase.auraacademy://login-callback',
    );
  }

  // Función para iniciar sesión con email y contraseña
  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Navegamos al Dashboard y limpiamos el stack de navegación
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error inesperado al iniciar sesión')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  void dispose() {
    // Liberamos los controladores al cerrar la pantalla
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo lavanda claro igual que la pantalla de bienvenida
      backgroundColor: const Color(0xFFF1F4FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Icono superior
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),

              const SizedBox(height: 20),

              // Nombre de la app
              Text(
                'Aura Academy',
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 8),

              // Subtítulo
              Text(
                'Expande tus horizontes cognitivos',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  color: const Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 40),

              // Tarjeta blanca con el formulario
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Campo de Correo Electrónico ---
                    Text(
                      'CORREO ELECTRÓNICO',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFF1E293B),
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ejemplo@aura.com',
                        hintStyle: GoogleFonts.montserrat(
                          color: const Color(0xFFCBD5E1),
                          fontSize: 15,
                        ),
                        prefixIcon: const Icon(
                          Icons.mail_outline_rounded,
                          color: Color(0xFFCBD5E1),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- Campo de Contraseña y Enlace "Olvidé" ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CONTRASEÑA',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 1.2,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFF1E293B),
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: '•••••••••',
                        hintStyle: GoogleFonts.montserrat(
                          color: const Color(0xFFCBD5E1),
                          fontSize: 20,
                          letterSpacing: 4,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFFCBD5E1),
                        ),
                        // Botón para mostrar/ocultar contraseña
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: const Color(0xFFCBD5E1),
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // --- Botón "Iniciar Sesión" con gradiente y lógica real ---
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isLoading
                              ? [Colors.grey.shade400, Colors.grey.shade400]
                              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isLoading ? [] : [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isLoading ? null : _login,
                          child: Center(
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Iniciar Sesión',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded,
                                          color: Colors.white),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // --- Divisor "O CONTINÚA CON" ---
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey[200],
                            thickness: 1.5,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'O CONTINÚA CON',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFCBD5E1),
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey[200],
                            thickness: 1.5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- Botones de Google y GitHub ---
                    Row(
                      children: [
                        // Botón Google
                        Expanded(
                          child: _SocialButton(
                            label: 'Google',
                            backgroundColor: const Color(0xFFF1F5F9),
                            textColor: const Color(0xFF1E293B),
                            icon: const FaIcon(FontAwesomeIcons.google,
                                color: Color(0xFFDB4437), size: 20),
                            onTap: _loginConGoogle, // Conectado a Supabase OAuth
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón GitHub (reemplaza Apple)
                        Expanded(
                          child: _SocialButton(
                            label: 'GitHub',
                            backgroundColor: const Color(0xFF1E293B),
                            textColor: Colors.white,
                            icon: const FaIcon(FontAwesomeIcons.github,
                                color: Colors.white, size: 24),
                            onTap: _loginConGitHub, // Conectado a Supabase OAuth
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- Enlace de Registro ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿No tienes cuenta?  ',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  GestureDetector(
                    // Navegar a la pantalla de Registro
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Regístrate',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget reutilizable para los botones sociales (Google y GitHub)
class _SocialButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Widget icon;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
