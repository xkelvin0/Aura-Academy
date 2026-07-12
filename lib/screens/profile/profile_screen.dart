import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_academy/screens/instructor/instructor_panel_screen.dart';
import 'package:aura_academy/screens/courses/my_courses_screen.dart';
import 'package:aura_academy/screens/certificates/certificates_screen.dart';
import 'package:aura_academy/screens/dashboard/wishlist_screen.dart';
import 'package:aura_academy/screens/profile/settings_screen.dart';
import 'package:aura_academy/screens/auth/welcome_screen.dart';
import 'package:aura_academy/screens/dashboard/leaderboard_screen.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  Stream<List<Map<String, dynamic>>>? _profileStream; // <--- Stream en tiempo real
  List<Map<String, dynamic>> _inProgressCourses = [];
  
  // Estadísticas reales
  int _completedCoursesCount = 0;
  int _certificatesCount = 0;
  double _totalStudyHours = 0.0;
  List<Map<String, dynamic>> _userMedals = [];

  @override
  void initState() {
    super.initState();
    _initRealtimeProfile();
    _loadProfileStats();
  }

  void _initRealtimeProfile() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      _profileStream = supabase
          .from('perfiles')
          .stream(primaryKey: ['id'])
          .eq('id', user.id);
    }
  }

  Future<void> _loadProfileStats() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // 1. Cargar cursos en progreso REALES
        List<Map<String, dynamic>> finalEnrollments = [];
        final profileRes = await supabase
            .from('perfiles')
            .select('*')
            .eq('id', user.id)
            .maybeSingle();
        _profileData = profileRes;

        final enrollments = await supabase
            .from('inscripciones')
            .select('*, cursos(*, categorias(nombre))')
            .eq('perfil_id', user.id)
            .eq('en_progreso', true);
        
        // Filtro manual para asegurar que no se vean cursos propios en progreso
        finalEnrollments = List<Map<String, dynamic>>.from(enrollments)
            .where((e) => e['cursos']['instructor_id'] != user.id)
            .toList();

        // 2. Consultas Analíticas Reales
        int completedCount = 0;
        int certsCount = 0;
        double studyHours = 0.0;

        try {
          final completedRes = await supabase
              .from('inscripciones')
              .select('id')
              .eq('perfil_id', user.id)
              .eq('progreso_porcentaje', 100)
              .count(CountOption.exact);
          completedCount = completedRes.count ?? 0;

          final certsRes = await supabase
              .from('certificados')
              .select('id')
              .eq('perfil_id', user.id)
              .count(CountOption.exact);
          certsCount = certsRes.count ?? 0;

          final statsRes = await supabase
              .from('perfiles')
              .select('horas_estudio_total, racha_dias')
              .eq('id', user.id)
              .single();
          
          debugPrint("DEBUG: Horas desde DB: ${statsRes['horas_estudio_total']}");
          studyHours = double.tryParse(statsRes['horas_estudio_total']?.toString() ?? "0.0") ?? 0.0;
        } catch (e) {
          debugPrint("Error cargando estadísticas analíticas: $e");
        }

        // 3. Cargar medallas ganadas
        List<Map<String, dynamic>> userMedals = [];
        try {
          final medalsRes = await supabase
              .from('perfiles_medallas')
              .select('*, medallas(*)')
              .eq('perfil_id', user.id);
          userMedals = List<Map<String, dynamic>>.from(medalsRes);
        } catch (medalErr) {
          debugPrint("Error al cargar medallas de Supabase: $medalErr");
        }

        setState(() {
          _inProgressCourses = finalEnrollments;
          _completedCoursesCount = completedCount;
          _certificatesCount = certsCount;
          _totalStudyHours = studyHours;
          _userMedals = userMedals;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error crítico cargando estadísticas: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        // Actualizamos _profileData CADA VEZ que el stream emite algo nuevo
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          _profileData = snapshot.data!.first;
          debugPrint("Stream detectó cambio: ${_profileData?['nombre_completo']}");
        }

        // ELIMINADO EL BLOQUEO TOTAL DE CARGA
        // Permitimos que la estructura se pinte de inmediato

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
              _buildLogoutButton(),
              const SizedBox(height: 40),
            ],
          ),
        );
      }
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
    final nombre = _profileData?['nombre_completo'] ?? "Usuario Aura";
    final avatarUrl = _profileData?['avatar_url'];
    // Comprobación robusta: no es null y no está vacío
    final bool hasAvatar = avatarUrl != null && avatarUrl.toString().trim().isNotEmpty;
    final iniciales = _getInitials(nombre);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFFE8E7FF),
              backgroundImage: hasAvatar ? NetworkImage(avatarUrl.toString()) : null,
              child: !hasAvatar 
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
          _profileData?['nombre_completo'] ?? "Usuario Aura",
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final bio = _profileData?['biografia']?.toString().trim() ?? "";
            return Text(
              bio.isEmpty 
                  ? "Todavía no tienes una biografía configurada. ¡Cuéntanos algo sobre ti!" 
                  : bio,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            );
          },
        ),
      ],
    );
  }

  // Tarjeta de Nivel y Puntos de Experiencia (Gamificación)
  Widget _buildXPCard() {
    final int xp = _profileData?['xp_total'] ?? 0;
    // Sistema XP progresivo: nivel N requiere N*200 XP para subir
    // XP acumulado para nivel N = 100 * N * (N-1)
    // Ej: nivel 2 = 200 XP, nivel 3 = 600 XP, nivel 4 = 1200 XP
    int nivel = 1;
    while (100 * nivel * (nivel + 1) <= xp) nivel++;
    final int xpParaNivelActual = 100 * (nivel - 1) * nivel;
    final int xpParaSiguienteNivel = 100 * nivel * (nivel + 1);
    final int xpEnNivelActual = xp - xpParaNivelActual;
    final int xpNecesarioEnNivel = xpParaSiguienteNivel - xpParaNivelActual;
    final double progresoNivel = (xpEnNivelActual / xpNecesarioEnNivel).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "NIVEL $nivel",
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Rango: Estudiante Aura",
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$xp XP",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: progresoNivel,
            backgroundColor: Colors.white.withOpacity(0.15),
            color: const Color(0xFF2DD4BF), // Turquesa premium para el progreso
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$xp / $xpParaSiguienteNivel XP",
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
              Text(
                "Nivel ${nivel + 1} en ${xpParaSiguienteNivel - xp} XP",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sección de Medallas / Insignias ganadas
  Widget _buildMedalsSection() {
    // Definimos las 4 medallas del sistema con sus correspondientes metadatos
    final List<Map<String, String>> medallasDelSistema = [
      {
        'tipo': 'PRIMERA_LECCION',
        'nombre': 'Paso Inicial',
        'desc': 'Completa tu primera lección en la plataforma.',
        'icono': 'play_circle_fill',
      },
      {
        'tipo': 'ESTUDIO_NOCTURNO',
        'nombre': 'Estudiante Nocturno',
        'desc': 'Completa una lección de estudio después de las 11:00 PM.',
        'icono': 'nights_stay',
      },
      {
        'tipo': 'RACHA_7',
        'nombre': 'Constancia Pura',
        'desc': 'Consigue una racha de estudio activa de 7 días.',
        'icono': 'local_fire_department',
      },
      {
        'tipo': 'PRIMER_DIPLOMA',
        'nombre': 'Devorador de Cursos',
        'desc': 'Gradúate y obtén tu primer diploma en Aura Academy.',
        'icono': 'school',
      },
    ];

    // Verificar cuáles de las medallas tiene el usuario realmente ganadas
    final ganadasTipos = _userMedals.map((m) => m['medallas']?['requisito_tipo']?.toString()).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Mis Medallas / Logros",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              "${ganadasTipos.length} de ${medallasDelSistema.length} obtenidas",
              style: GoogleFonts.outfit(
                color: const Color(0xFF6366F1),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: medallasDelSistema.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final medalla = medallasDelSistema[index];
            final bool hasEarned = ganadasTipos.contains(medalla['tipo']);

            IconData iconData;
            switch (medalla['icono']) {
              case 'nights_stay':
                iconData = Icons.nights_stay_rounded;
                break;
              case 'local_fire_department':
                iconData = Icons.local_fire_department_rounded;
                break;
              case 'school':
                iconData = Icons.school_rounded;
                break;
              default:
                iconData = Icons.play_circle_fill_rounded;
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasEarned ? const Color(0xFFF5F3FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasEarned ? const Color(0xFFC7D2FE) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconData,
                    color: hasEarned ? const Color(0xFF6366F1) : Colors.grey.shade400,
                    size: 26,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    medalla['nombre']!,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: hasEarned ? const Color(0xFF1E293B) : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    medalla['desc']!,
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      color: Colors.grey.shade500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // Muestra el bottom sheet premium con la tabla de clasificación semanal
  void _showLeaderboardBottomSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchLeaderboardData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    "No hay clasificaciones registradas esta semana.",
                    style: GoogleFonts.outfit(color: Colors.grey),
                  ),
                );
              }

              final ranking = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 28),
                      const SizedBox(width: 10),
                      Text(
                        "Clasificación Semanal",
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Estudiantes con más constancia esta semana en Aura Academy",
                    style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  // Lista de clasificación
                  Expanded(
                    child: ListView.builder(
                      itemCount: ranking.length,
                      itemBuilder: (context, idx) {
                        final item = ranking[idx];
                        final perfil = item['perfiles'];
                        final double horas = double.tryParse(item['horas_estudiadas']?.toString() ?? '0.0') ?? 0.0;
                        final String nombre = perfil?['nombre_completo'] ?? "Usuario Aura";
                        final String avatar = perfil?['avatar_url'] ?? "";

                        // Puestos destacados con colores
                        Color itemColor = const Color(0xFFF8FAFC);
                        Widget leadWidget = Text(
                          "${idx + 1}",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                        );

                        if (idx == 0) {
                          itemColor = const Color(0xFFFEF3C7); // Dorado
                          leadWidget = const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 22);
                        } else if (idx == 1) {
                          itemColor = const Color(0xFFF1F5F9); // Plata
                          leadWidget = const Icon(Icons.emoji_events_rounded, color: Color(0xFF64748B), size: 22);
                        } else if (idx == 2) {
                          itemColor = const Color(0xFFFFEDD5); // Bronce
                          leadWidget = const Icon(Icons.emoji_events_rounded, color: Color(0xFFC2410C), size: 22);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: itemColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 24, child: Center(child: leadWidget)),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFE2E8F0),
                                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                child: avatar.isEmpty
                                    ? Text(
                                        nombre.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  nombre,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                "${horas}h",
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF6366F1),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Método auxiliar para consultar los datos del ranking de metas semanales de esta semana
  Future<List<Map<String, dynamic>>> _fetchLeaderboardData() async {
    final vLunes = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final String semanaInicioStr = "${vLunes.year}-${vLunes.month.toString().padLeft(2, '0')}-${vLunes.day.toString().padLeft(2, '0')}";

    try {
      final res = await supabase
          .from('metas_semanales')
          .select('*, perfiles(*)')
          .eq('semana_inicio', semanaInicioStr)
          .order('horas_estudiadas', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("Error consultando metas_semanales: $e");
      return [];
    }
  }

  String _formatStudyTime(double decimalHours) {
    int totalMinutes = (decimalHours * 60).round();
    if (totalMinutes < 60) return "$totalMinutes min";
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    if (minutes == 0) return "${hours}h";
    return "${hours}h ${minutes}m";
  }

  Widget _buildStats() {
    final horas = double.tryParse(_profileData?['horas_estudio_total']?.toString() ?? "0.0") ?? 0.0;
    final cursCompletados = _profileData?['cursos_completados'] ?? _completedCoursesCount;
    final certsCount = _profileData?['certificados_count'] ?? _certificatesCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildStatItem(cursCompletados.toString(), "CURSOS", "COMPLETADOS")),
        const SizedBox(width: 8),
        Expanded(child: _buildStatItem(certsCount.toString(), "CERTIFICADOS", "")),
        const SizedBox(width: 8),
        Expanded(child: _buildStatItem(_formatStudyTime(horas.toDouble()), "HORAS DE", "ESTUDIO")),
      ],
    );
  }

  Widget _buildStatItem(String value, String labelPart1, String labelPart2) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6366F1),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            labelPart1,
            style: GoogleFonts.montserrat(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
          if (labelPart2.isNotEmpty)
            Text(
              labelPart2,
              style: GoogleFonts.montserrat(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
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
          await _loadProfileStats(); // Recarga toda la pantalla y esconde el botón
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InstructorPanelScreen()),
              );
            },
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyCoursesScreen()),
            ).then((_) => _loadProfileStats());
          },
        ),
        _buildListTile(
          Icons.workspace_premium_rounded, 
          "Certificados",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CertificatesScreen()),
            );
          },
        ),
        _buildListTile(
          Icons.emoji_events_rounded, 
          "Centro de Logros",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
            ).then((_) => _loadProfileStats());
          },
        ),
        _buildListTile(
          Icons.favorite_rounded, 
          "Lista de Deseos",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WishlistScreen()),
            );
          },
        ),
        _buildListTile(
          Icons.settings_rounded, 
          "Configuración",
          onTap: () async {
            // Esperar a que el usuario regrese de configuración
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
            // Al volver, refrescar los datos del perfil
            _loadProfileStats();
          },
        ),
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

  Widget _buildListTile(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {
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
    final int racha = _profileData?['racha_dias'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt, color: Color(0xFF6366F1), size: 24),
          const SizedBox(height: 16),
          const Text("Impulso Diario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            racha == 0 
              ? "Aún no has iniciado tu racha. ¡Estudia hoy mismo para empezar!"
              : "Has estudiado durante $racha ${racha == 1 ? 'día' : 'días'} consecutivos. ¡Mantén la racha!",
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(7, (index) {
              // Por ahora, como es visual, marcamos el primer día si la racha es >= 1
              bool isActive = index < racha;
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

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("¿Cerrar Sesión?"),
              content: const Text("¿Estás seguro de que deseas salir de Aura Academy?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
                TextButton(
                  onPressed: () => Navigator.pop(context, true), 
                  child: const Text("Salir", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await supabase.auth.signOut();
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (route) => false,
              );
            }
          }
        },
        icon: const Icon(Icons.logout_rounded, color: Colors.red),
        label: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Color(0xFFFEE2E2)), // Rojo muy suave
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: const Color(0xFFFEF2F2),
        ),
      ),
    );
  }
}





