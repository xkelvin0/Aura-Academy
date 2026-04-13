import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _inProgressCourses = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Extraemos metadatos de Google
        final meta = user.userMetadata;
        final googleName = meta?['full_name'] ?? meta?['name'] ?? 'Usuario Nómada';
        final googleAvatar = meta?['avatar_url'] ?? meta?['picture'];

        Map<String, dynamic>? profile;
        try {
          // 1. Intentar cargar datos de la tabla perfiles
          profile = await supabase
              .from('perfiles')
              .select()
              .eq('id', user.id)
              .single();
        } catch (e) {
          debugPrint("No hay registro en BD. Usando metadata de Google.");
          // Perfil temporal usando la información de Google
          profile = {
            'nombre_completo': googleName,
            'biografia': 'Recién llegado a Aura Academy. ¡A punto de brillar!',
            'avatar_url': googleAvatar,
            'cursos_completados': 0,
            'certificados_count': 0,
            'horas_estudio_total': 0,
            'racha_dias': 0,
            'es_instructor': false,
          };
        }

        // 2. Cargar cursos en progreso REALES
        List<Map<String, dynamic>> finalEnrollments = [];
        try {
          final enrollments = await supabase
              .from('inscripciones')
              .select('*, cursos(*, categorias(nombre))')
              .eq('perfil_id', user.id)
              .eq('en_progreso', true);
          finalEnrollments = List<Map<String, dynamic>>.from(enrollments);
        } catch (e) {
          debugPrint("Error consultando inscripciones: $e");
        }

        setState(() {
          _profileData = profile;
          _inProgressCourses = finalEnrollments;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error crítico cargando perfil: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStats(),
          const SizedBox(height: 32),
          _buildAccessMenu(),
          const SizedBox(height: 32),
          _buildDailyImpulse(),
          const SizedBox(height: 32),
          _buildInProgressSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Algoritmo para extraer iniciales: Primer Nombre + Apellido Paterno (3ra palabra si existe)
  String _getInitials(String name) {
    if (name.isEmpty) return "U";
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return "U";
    if (parts.length == 1) return parts[0][0].toUpperCase();
    if (parts.length >= 3) return "${parts[0][0]}${parts[2][0]}".toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  Widget _buildHeader() {
    final nombre = _profileData?['nombre_completo'] ?? "Usuario Aura (Cargando...)";
    final avatarUrl = _profileData?['avatar_url'];
    final iniciales = _getInitials(nombre);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFFE8E7FF),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null 
                  ? Text(
                      iniciales, 
                      style: GoogleFonts.montserrat(
                        fontSize: 36, 
                        fontWeight: FontWeight.bold, 
                        color: const Color(0xFF6366F1)
                      )
                    ) 
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF2DD4BF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _profileData?['nombre_completo'] ?? "Usuario Aura (Cargando...)",
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _profileData?['biografia'] ?? "Todavía no tienes una biografía configurada.",
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildStatItem(_profileData?['cursos_completados']?.toString() ?? "12", "CURSOS COMPLETADOS")),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem("0${_profileData?['certificados_count'] ?? "8"}", "CERTIFICADOS")),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem(_profileData?['horas_estudio_total'] ?? "1.2k", "HORAS DE ESTUDIO")),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF94A3B8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _upgradeToInstructor() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.campaign_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text("¿Ser Instructor?"),
          ],
        ),
        content: const Text(
          "Al convertirte en instructor, podrás crear cursos de alto nivel y gestionar alumnos internacionales.\n\n¿Estás listo para compartir tu conocimiento?",
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Quizás Luego", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Sí, ¡Empecemos!"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = supabase.auth.currentUser;
      if (user != null) {
        setState(() => _isLoading = true);
        try {
          await supabase.from('perfiles').update({'es_instructor': true}).eq('id', user.id);
          await _loadProfile(); // Recarga toda la pantalla y esconde el botón
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Felicidades! Tu cuenta ahora es nivel Instructor 🎓'),
                backgroundColor: Color(0xFF0D9488),
              ),
            );
          }
        } catch (e) {
          debugPrint("Error actualizando a instructor: $e");
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hubo un error al actualizar el perfil en la base de datos.'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  Widget _buildAccessMenu() {
    final bool esInstructor = _profileData?['es_instructor'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Biblioteca y Acceso", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        
        if (esInstructor) ...[
          _buildMenuItem(
            label: "Panel de Instructor", 
            icon: Icons.school_rounded, 
            color: const Color(0xFFE8E7FF), 
            textColor: const Color(0xFF6366F1),
            isPrimary: false,
          ),
          const SizedBox(height: 8),
        ] else ...[
          _buildMenuItem(
            label: "Conviértete en Instructor", 
            icon: Icons.campaign_rounded, 
            color: const Color(0xFFFEF3C7), // Dorado suave
            textColor: const Color(0xFFD97706), // Ámbar fuerte
            isPrimary: false,
            onTap: _upgradeToInstructor,
          ),
          const SizedBox(height: 8),
        ],

        _buildMenuItem(
          label: "Mis Cursos", 
          icon: Icons.play_circle_fill_rounded, 
          color: const Color(0xFF6366F1), 
          textColor: Colors.white,
          isPrimary: true,
        ),
        _buildListTile(Icons.workspace_premium_rounded, "Certificados"),
        _buildListTile(Icons.favorite_rounded, "Lista de Deseos"),
        _buildListTile(Icons.settings_rounded, "Configuración"),
      ],
    );
  }

  Widget _buildMenuItem({
    required String label, 
    required IconData icon, 
    required Color color, 
    required Color textColor, 
    required bool isPrimary,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Excelente elección! La función "$label" está en construcción. 🚀'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
            Icon(Icons.chevron_right_rounded, color: textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String label) {
    return InkWell(
      onTap: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Configuración "$label" en desarrollo. 🛠️'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF64748B), size: 22),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyImpulse() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(FontAwesomeIcons.bolt, color: Color(0xFF6366F1), size: 24),
          const SizedBox(height: 16),
          const Text("Impulso Diario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            "Has estudiado durante ${_profileData?['racha_dias'] ?? 5} días consecutivos. ¡Mantén la racha!",
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(7, (index) {
              bool isActive = index < (_profileData?['racha_dias'] ?? 5);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 30,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("En Progreso", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
            TextButton(
              onPressed: () {}, 
              child: const Text("Ver Todo", style: TextStyle(color: Color(0xFF6366F1)))
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_inProgressCourses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("Cero cursos en progreso. ¡Empieza a aprender hoy!", style: TextStyle(color: Colors.grey)),
          )
        else
          ..._inProgressCourses.map((enroll) {
            final curso = enroll['cursos'];
            final categoria = curso['categorias']?['nombre'] ?? "GENERAL";
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildCourseProgressItem(
                curso['titulo'] ?? "Sin título",
                categoria.toString().toUpperCase(),
                (enroll['progreso_porcentaje'] ?? 0) / 100,
                "${enroll['progreso_porcentaje'] ?? 0}%",
                "Siguiente lección...", // Aquí podrías jalar el nombre de la lección si quisieras
                curso['thumbnail_url'] ?? "https://images.unsplash.com/photo-1550751827-4bd374c3f58b?auto=format&fit=crop&q=80&w=400",
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCourseProgressItem(String title, String category, double progress, String percent, String nextLesson, String imageUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D9488), letterSpacing: 1)),
                    Text(percent, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: const Color(0xFF0D9488),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.play_circle_outline_rounded, color: Color(0xFF64748B), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Siguiente: ", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          Text(nextLesson, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE2E8F0),
                        foregroundColor: const Color(0xFF1E293B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Reanudar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
