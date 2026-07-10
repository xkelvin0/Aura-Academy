import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_academy/screens/courses/course_detail_screen.dart';
import 'package:aura_academy/screens/courses/lesson_player_screen.dart';
import 'package:aura_academy/screens/dashboard/dashboard_screen.dart'; // <--- Para el controlador de updates
import 'package:aura_academy/screens/instructor/create_course_screen.dart';

class MyCoursesScreen extends StatefulWidget {
  final VoidCallback? onBack; // <--- Callback para volver
  const MyCoursesScreen({super.key, this.onBack});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _myCourses = [];
  List<Map<String, dynamic>> _createdCourses = []; // <--- Nueva lista para instructores
  bool _isInstructor = false; // <--- Nuevo flag de rol
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;
  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();
    _loadMyCourses();

    // Sincronización Global
    _updateSubscription = DashboardScreen.courseUpdateController.stream.listen((_) {
      if (mounted) _loadMyCourses();
    });

    // Realtime Database Sync
    _realtimeChannel = supabase
        .channel('public:courses_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cursos',
          callback: (payload) {
            if (mounted) _loadMyCourses();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inscripciones',
          callback: (payload) {
            if (mounted) _loadMyCourses();
          },
        );
    _realtimeChannel!.subscribe();
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _loadMyCourses() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Obtener rol
      final profile = await supabase.from('perfiles').select('es_instructor').eq('id', user.id).single();
      final bool esInst = profile['es_instructor'] == true;

      // 2. Obtener inscripciones (Lo que está aprendiendo)
      final enrollRes = await supabase
          .from('inscripciones')
          .select('*, cursos(*, categorias(nombre), perfiles!instructor_id(nombre_completo))')
          .eq('perfil_id', user.id)
          .order('ultima_vez_visto', ascending: false);

      // 3. Obtener cursos creados (Si es instructor)
      List<Map<String, dynamic>> createdRes = [];
      if (esInst) {
        final res = await supabase
            .from('cursos')
            .select('*, categorias(nombre)')
            .eq('instructor_id', user.id)
            .order('fecha_creacion', ascending: false);
        createdRes = List<Map<String, dynamic>>.from(res);
      }

      if (mounted) {
        setState(() {
          _isInstructor = esInst;
          _myCourses = List<Map<String, dynamic>>.from(enrollRes)
              .where((e) => e['cursos']['instructor_id'] != user.id) // Filtrar propios
              .toList();
          _createdCourses = createdRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando mis cursos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInstructor) {
      return _buildStudentView();
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
              else if (widget.onBack != null) widget.onBack!();
            },
            icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B)),
          ),
          title: Text(
            "Mis Contenidos",
            style: GoogleFonts.montserrat(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            labelColor: const Color(0xFF6366F1),
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: const Color(0xFF6366F1),
            labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: "APRENDIZAJES", icon: Icon(Icons.school_rounded, size: 20)),
              Tab(text: "MIS CURSOS", icon: Icon(Icons.dashboard_customize_rounded, size: 20)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _isLoading && _myCourses.isEmpty 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) 
              : _buildLearningTab(),
            _isLoading && _createdCourses.isEmpty 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))) 
              : _buildTeachingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentView() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else if (widget.onBack != null) {
              widget.onBack!();
            }
          },
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color, size: 24),
        ),
        title: Text(
          "Mis Aprendizajes",
          style: GoogleFonts.montserrat(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                "Continúa donde lo dejaste",
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ),
            Expanded(
              child: _isLoading && _myCourses.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : _myCourses.isEmpty
                      ? _buildEmptyState(true)
                      : _buildCoursesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningTab() {
    if (_myCourses.isEmpty) return _buildEmptyState(true);
    return _buildCoursesList();
  }

  Widget _buildTeachingTab() {
    if (_createdCourses.isEmpty) return _buildEmptyState(false);
    return RefreshIndicator(
      onRefresh: _loadMyCourses,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _createdCourses.length,
        itemBuilder: (context, index) {
          final curso = _createdCourses[index];
          return _buildCreatedCourseCard(curso);
        },
      ),
    );
  }

  Widget _buildCreatedCourseCard(Map<String, dynamic> curso) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CourseDetailScreen(courseId: curso['id'])),
        ).then((_) => _loadMyCourses()),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  curso['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=200',
                  width: 70, height: 70, fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(curso['titulo'] ?? "Sin Título", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text(curso['categorias']?['nombre'] ?? "General", style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        const Text("Gestionar alumnos", style: TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Stats del curso para el instructor
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          ((curso['rating_promedio'] ?? 0.0) as num).toDouble().toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF94A3B8), size: 12),
                        const SizedBox(width: 4),
                        Text("${curso['vistas'] ?? 0}", style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        const SizedBox(width: 8),
                        const Icon(Icons.favorite_rounded, color: Colors.red, size: 10),
                        const SizedBox(width: 4),
                        Text("${curso['likes_count'] ?? 0}", style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEmptyState(bool isLearning) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLearning ? Icons.auto_stories_rounded : Icons.folder_off_rounded, 
            size: 80, 
            color: Theme.of(context).primaryColor.withOpacity(0.2)
          ),
          const SizedBox(height: 24),
          Text(
            isLearning ? "No tienes cursos todavía" : "No has creado cursos aún",
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isLearning ? "¡Explora el catálogo y comienza a aprender!" : "Comienza a compartir tu conocimiento.", 
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7))
          ),
          if (!isLearning) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateCourseScreen()),
                ).then((_) {
                  _loadMyCourses(); // Recargar al volver si creó uno
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text("Crear mi primer curso"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    return RefreshIndicator(
      onRefresh: _loadMyCourses,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _myCourses.length,
        itemBuilder: (context, index) {
          final inscripcion = _myCourses[index];
          final curso = inscripcion['cursos'];
          final progreso = inscripcion['progreso_porcentaje'] ?? 0;
          final categoria = curso['categorias']?['nombre'] ?? "General";
          final double rating = (curso['rating_promedio'] ?? 0.0).toDouble();

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CourseDetailScreen(courseId: curso['id'])),
                ).then((_) => _loadMyCourses());
              },
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        curso['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=200',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            curso['titulo'] ?? "Sin Título",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            categoria,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                              const SizedBox(width: 2),
                              Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF94A3B8), size: 12),
                              const SizedBox(width: 4),
                              Text("${curso['vistas'] ?? 0}", style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              const SizedBox(width: 8),
                              const Icon(Icons.favorite_rounded, color: Colors.red, size: 10),
                              const SizedBox(width: 4),
                              Text("${curso['likes_count'] ?? 0}", style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: progreso / 100,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  color: const Color(0xFF6366F1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "$progreso%",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF6366F1), size: 24),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}





