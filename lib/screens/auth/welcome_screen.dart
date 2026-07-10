import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aura_academy/screens/auth/login_screen.dart'; // Importamos la pantalla de login

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el tamaño de la pantalla para cálculos de diseño
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FF), // Fondo lavanda muy claro como en el original
      body: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            // Capa de fondo y contenido superior
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // 1. Cabecera (Nombre y Saltar)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Aura Academy',
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFF1E293B),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'SALTAR',
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFF6366F1),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Texto secundario superior
              Text(
                'UNIVERSO DEL APRENDIZAJE',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'EXPLORA. APRENDE. CRECE.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 32),

              // 3. Área de la Imagen Central
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: size.height * 0.35,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    'assets/onboarding.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),

          // 4. Tarjeta Blanca Inferior (Bottom Card)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: size.height * 0.45,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 30,
                    offset: Offset(0, -10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  children: [
                    // Puntos indicadores
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 35,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Título
                    Text(
                      'Domina tu Futuro',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    Text(
                      'Aprende de los mejores expertos en tecnología y diseño con cursos prácticos y certificados.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),

                    // Botón "Siguiente"
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          // Navegar a la pantalla de Login al presionar
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Siguiente',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pie de página
                    Text(
                      'EMPODERANDO EL APRENDIZAJE DIGITAL',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}





