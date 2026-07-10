import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:aura_academy/screens/certificates/certificates_screen.dart';

class GraduationCelebrationScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const GraduationCelebrationScreen({
    super.key, 
    required this.courseId, 
    required this.courseTitle
  });

  @override
  State<GraduationCelebrationScreen> createState() => _GraduationCelebrationScreenState();
}

class _GraduationCelebrationScreenState extends State<GraduationCelebrationScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _scaleAnimation;
  final List<ConfettiPart> _confetti = [];
  final supabase = Supabase.instance.client;
  final _audioPlayer = AudioPlayer();
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUser();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _scaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: Curves.elasticOut,
    );

    // Generar confeti inicial
    for (int i = 0; i < 100; i++) {
      _confetti.add(ConfettiPart());
    }

    // DISPARAR AUDIO DE VICTORIA
    _playSuccessSound();

    // GENERAR O VERIFICAR CERTIFICADO
    _generateCertificate();
  }

  Future<void> _generateCertificate() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Verificar si ya existe un certificado para este curso
      final existing = await supabase
          .from('certificados')
          .select()
          .eq('perfil_id', user.id)
          .eq('curso_id', widget.courseId)
          .maybeSingle();

      if (existing == null) {
        // 2. Si no existe, crear uno nuevo
        final String hash = "AURA-${widget.courseId.substring(0,4)}-${user.id.substring(0,4)}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}".toUpperCase();
        
        await supabase.from('certificados').insert({
          'perfil_id': user.id,
          'curso_id': widget.courseId,
          'fecha_emision': DateTime.now().toIso8601String(),
          'hash_validacion': hash,
        });
        debugPrint("Certificado nuevo generado: $hash");
      } else {
        debugPrint("El usuario ya tiene un certificado para este curso.");
      }
    } catch (e) {
      debugPrint("Error al gestionar certificado: $e");
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/success_cheer.mp3'));
    } catch (e) {
      debugPrint("Error al reproducir audio: $e");
    }
  }

  Future<void> _loadUser() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase.from('perfiles').select().eq('id', user.id).single();
      setState(() => _userData = data);
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // FONDO CON GRADIENTE PREMIUM
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFD946EF)],
              ),
            ),
          ),

          // ANIMACIÓN DE CONFETI (Simple y efectiva)
          ..._confetti.map((c) => AnimatedConfetti(part: c)),

          // CONTENIDO CENTRAL
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 30),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // AVATAR CON CORONA
                    Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _userData?['avatar_url'] != null 
                              ? NetworkImage(_userData!['avatar_url'])
                              : null,
                            child: _userData?['avatar_url'] == null 
                              ? const Icon(Icons.person, size: 50) 
                              : null,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -25),
                          child: const Text("👑", style: TextStyle(fontSize: 40)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "¡FELICITACIONES!",
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userData?['nombre_completo']?.split(' ')[0].toUpperCase() ?? "ESTUDIANTE",
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      "Has completado con éxito el curso:",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.courseTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const CertificatesScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 10,
                        shadowColor: const Color(0xFF6366F1).withOpacity(0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.workspace_premium_rounded),
                          SizedBox(width: 12),
                          Text("VER MI CERTIFICADO", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Volver al curso", style: TextStyle(color: Colors.grey[500])),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Lógica simple para confeti animado
class ConfettiPart {
  late double x;
  late double y;
  late Color color;
  late double size;
  late double speed;

  ConfettiPart() {
    x = Random().nextDouble();
    y = Random().nextDouble() * -1;
    color = Colors.primaries[Random().nextInt(Colors.primaries.length)];
    size = Random().nextDouble() * 10 + 5;
    speed = Random().nextDouble() * 0.01 + 0.005;
  }
}

class AnimatedConfetti extends StatefulWidget {
  final ConfettiPart part;
  const AnimatedConfetti({super.key, required this.part});

  @override
  State<AnimatedConfetti> createState() => _AnimatedConfettiState();
}

class _AnimatedConfettiState extends State<AnimatedConfetti> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _y;

  @override
  void initState() {
    super.initState();
    _y = widget.part.y;
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _controller.addListener(() {
      setState(() {
        _y += widget.part.speed;
        if (_y > 1) _y = -0.1;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(widget.part.x * 2 - 1, _y * 2 - 1),
      child: Container(
        width: widget.part.size,
        height: widget.part.size,
        decoration: BoxDecoration(
          color: widget.part.color,
          shape: Random().nextBool() ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}





