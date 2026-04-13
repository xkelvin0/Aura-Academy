import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dashboard_screen.dart'; // Importamos el dashboard

// Pantalla de registro de nuevo usuario
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para cada campo del formulario
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Estado del ojo de la contraseña, checkbox de términos y carga
  bool _passwordVisible = false;
  bool _acceptedTerms = false;
  bool _isLoading = false; // Controla el indicador de carga al registrarse

  @override
  void dispose() {
    // Liberamos memoria al salir de la pantalla
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Función para registrarse con Google
  Future<void> _registrarConGoogle() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.auraacademy://login-callback',
    );
  }

  // Función para registrarse con GitHub
  Future<void> _registrarConGitHub() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: 'io.supabase.auraacademy://login-callback',
    );
  }

  Future<void> _registrarse() async {
    // Validaciones básicas antes de llamar a Supabase
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debes aceptar los Términos y Condiciones')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Paso 1: Crear el usuario en Supabase Auth
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Paso 2: Si el usuario se creó, guardamos su perfil en la tabla "perfiles"
      if (response.user != null) {
        try {
          await Supabase.instance.client.from('perfiles').insert({
            'id': response.user!.id,
            'nombre_completo': _nameController.text.trim(),
            'email': _emailController.text.trim(),
          });
        } catch (dbError) {
          // El error 42501 es RLS. Si falla la inserción pero el auth funcionó, avanzamos.
          debugPrint("Advertencia DB (RLS o Trigger): $dbError");
        }

        if (mounted) {
          // Mostramos mensaje de éxito y regresamos al Login
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Cuenta creada con éxito! Inicia sesión.'),
              backgroundColor: Color(0xFF6366F1),
            ),
          );
          // Navegamos al Dashboard (Fase 6)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      // Errores de autenticación de Supabase
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      // Diferenciar errores de base de datos u otras fallas
      debugPrint("Error crítico en el registro: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FF), // Fondo lavanda claro
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Barra superior: Logo, nombre y botón cerrar ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Ícono de bombilla
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.lightbulb_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Aura Academy',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  // Botón cerrar (X)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // --- Títulos de la pantalla ---
              Text(
                'Crea tu Cuenta',
                style: GoogleFonts.montserrat(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Únete a la galería del conocimiento y comienza tu viaje.',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 36),

              // --- Campo: Nombre Completo ---
              _buildLabel('Nombre completo'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hintText: 'John Doe',
                keyboardType: TextInputType.name,
                prefixIcon: null,
              ),

              const SizedBox(height: 20),

              // --- Campo: Correo Electrónico ---
              _buildLabel('Correo electrónico'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hintText: 'email@ejemplo.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: null,
              ),

              const SizedBox(height: 20),

              // --- Campo: Contraseña con ojo ---
              _buildLabel('Contraseña'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                style: GoogleFonts.montserrat(
                  color: const Color(0xFF1E293B),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: GoogleFonts.montserrat(
                    color: const Color(0xFFCBD5E1),
                    fontSize: 20,
                    letterSpacing: 4,
                  ),
                  // Botón para mostrar u ocultar la contraseña
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
                  fillColor: Colors.white,
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

              // --- Checkbox de Términos y Condiciones ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _acceptedTerms,
                      activeColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _acceptedTerms = value ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'Acepto los '),
                          TextSpan(
                            text: 'Términos y Condiciones',
                            style: GoogleFonts.montserrat(
                              color: const Color(0xFF6366F1),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const TextSpan(text: ' y la '),
                          TextSpan(
                            text: 'Política de Privacidad',
                            style: GoogleFonts.montserrat(
                              color: const Color(0xFF6366F1),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const TextSpan(text: ' de Aura.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- Botón "Registrarse" con gradiente y lógica de Supabase ---
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
                    // Llama a la función de registro con Supabase
                    onTap: _isLoading ? null : _registrarse,
                    child: Center(
                      child: _isLoading
                          // Spinner mientras se procesa el registro
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Registrarse',
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
                    child: Divider(color: Colors.grey[300], thickness: 1.5),
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
                    child: Divider(color: Colors.grey[300], thickness: 1.5),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- Botones sociales (ambos claros en esta pantalla) ---
              Row(
                children: [
                  // Botón Google
                  Expanded(
                    child: _SocialButtonRegister(
                      label: 'Google',
                      icon: const FaIcon(FontAwesomeIcons.google,
                          color: Color(0xFFDB4437), size: 20),
                      onTap: _registrarConGoogle, // OAuth con Supabase
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botón GitHub (reemplaza Apple)
                  Expanded(
                    child: _SocialButtonRegister(
                      label: 'GitHub',
                      icon: const FaIcon(FontAwesomeIcons.github,
                          color: Color(0xFF1E293B), size: 24),
                      onTap: _registrarConGitHub, // OAuth con Supabase
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- Enlace para ir al Login ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Ya tienes cuenta?  ',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context), // Regresa al Login
                    child: Text(
                      'Inicia Sesión',
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

  // Widget reutilizable para las etiquetas de los campos del formulario
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      ),
    );
  }

  // Widget reutilizable para los campos de texto del formulario
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
    Widget? prefixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.montserrat(
        color: const Color(0xFF1E293B),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.montserrat(
          color: const Color(0xFFCBD5E1),
          fontSize: 15,
        ),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: Colors.white,
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
    );
  }
}

// Widget privado para los botones sociales de la pantalla de registro
class _SocialButtonRegister extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const _SocialButtonRegister({
    required this.label,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: const Color(0xFF1E293B),
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
