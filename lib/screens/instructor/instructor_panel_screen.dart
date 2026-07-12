import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_academy/screens/instructor/create_course_screen.dart';
import 'package:aura_academy/screens/courses/course_detail_screen.dart';
import 'package:aura_academy/screens/instructor/instructor_monitoring_screen.dart';
import 'package:aura_academy/screens/dashboard/dashboard_screen.dart'; // <--- Para sincronización global
import 'dart:async';

class InstructorPanelScreen extends StatefulWidget {
  const InstructorPanelScreen({super.key});

  @override
  State<InstructorPanelScreen> createState() => _InstructorPanelScreenState();
}

class _InstructorPanelScreenState extends State<InstructorPanelScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _selectedIndex = 0; // <--- Control de pestañas
  String _instructorName = "Profesor";
  
  // Variables 100% Reales
  int _totalStudents = 0;
  int _totalViews = 0;
  int _totalLikes = 0; // <--- Nueva métrica
  double _totalRevenue = 0.0;
  double _avgRating = 0.0;
  List<Map<String, dynamic>> _myCourses = [];
  List<Map<String, dynamic>> _recentActivity = [];
  Map<String, dynamic>? _topCourse;
  List<double> _weeklyRevenue = [0, 0, 0, 0, 0, 0, 0];
  RealtimeChannel? _realtimeChannel; // <--- Suscripción Realtime

  @override
  void initState() {
    super.initState();
    _loadData();
    _initRealtimeSync(); // <--- Iniciar escucha global

    // Sincronización Local (misma app)
    DashboardScreen.courseUpdateController.stream.listen((_) {
      if (mounted) _loadData();
    });
  }

  void _initRealtimeSync() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Escuchar cambios en Cursos (Likes, Vistas, Rating) e Inscripciones (Nuevos alumnos)
    _realtimeChannel = supabase.channel('instructor_sync_${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'cursos',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'instructor_id', value: user.id),
        callback: (payload) {
          debugPrint("📡 Cambio detectado en curso: RECARGANDO...");
          if (mounted) _loadData();
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'inscripciones',
        callback: (payload) {
          // Nota: Aquí se podría filtrar más, pero por ahora refrescamos ante cualquier inscripción
          debugPrint("📡 Nueva inscripción detectada: RECARGANDO...");
          if (mounted) _loadData();
        },
      )
      .subscribe();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe(); // <--- Limpiar para evitar fugas de memoria
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profile = await supabase.from('perfiles').select('nombre_completo').eq('id', user.id).single();
        
        // 1. Extraer Cursos del Instructor
        final rawCourses = await supabase.from('cursos').select('*, inscripciones(perfil_id)').eq('instructor_id', user.id);
            
        // 2. Extraer Actividad Reciente
        List<dynamic> activityRes = [];
        try {
          final myCourseIds = (rawCourses as List).map((c) => c['id']).toList();
          
          if (myCourseIds.isNotEmpty) {
            final inscRes = await supabase
                .from('inscripciones')
                .select('created_at, perfiles(nombre_completo), cursos(titulo)')
                .inFilter('curso_id', myCourseIds)
                .order('created_at', ascending: false)
                .limit(5);

            final certRes = await supabase
                .from('certificados')
                .select('fecha_emision, perfiles(nombre_completo), cursos(titulo)')
                .inFilter('curso_id', myCourseIds)
                .order('fecha_emision', ascending: false)
                .limit(5);
                
            List<Map<String, dynamic>> combinedActivity = [];
            for (var ins in inscRes) {
              combinedActivity.add({
                'tipo': 'inscripcion',
                'fecha': ins['created_at'],
                'alumno': ins['perfiles']['nombre_completo'],
                'curso': ins['cursos']['titulo'],
              });
            }
            for (var cert in certRes) {
              combinedActivity.add({
                'tipo': 'graduacion',
                'fecha': cert['fecha_emision'],
                'alumno': cert['perfiles']['nombre_completo'],
                'curso': cert['cursos']['titulo'],
              });
            }
            combinedActivity.sort((a, b) => b['fecha'].compareTo(a['fecha']));
            activityRes = combinedActivity.take(5).toList();
                
            // --- CÁLCULO PARA EL GRÁFICO (Últimos 7 días) ---
            final now = DateTime.now();
            final sevenDaysAgo = now.subtract(const Duration(days: 7));
            
            final weeklyInsc = await supabase
                .from('inscripciones')
                .select('created_at, curso_id, cursos(precio)')
                .inFilter('curso_id', myCourseIds)
                .gte('created_at', sevenDaysAgo.toIso8601String());

            List<double> dailyRev = [0, 0, 0, 0, 0, 0, 0];
            for (var ins in weeklyInsc) {
              final date = DateTime.parse(ins['created_at']);
              final dayIndex = 6 - now.difference(date).inDays;
              if (dayIndex >= 0 && dayIndex < 7) {
                final double precio = (ins['cursos']['precio'] ?? 0).toDouble();
                dailyRev[dayIndex] += precio;
              }
            }
            _weeklyRevenue = dailyRev;
          }
        } catch (e) {
          debugPrint("Error actividad/grafico: $e");
        }

        final List<Map<String, dynamic>> courses = [];
        int globalStudents = 0;
        int globalLikes = 0;
        double globalRevenue = 0.0;
        double totalRating = 0.0;
        int coursesWithRating = 0;
        int totalV = 0;
        
        Map<String, dynamic>? topCourseCandidate;
        int maxStudents = -1;

        for (var row in rawCourses) {
          final List inscritos = row['inscripciones'] ?? [];
          final int courseStudents = inscritos.where((i) => i['perfil_id'] != user.id).length;
          final double precio = (row['precio'] ?? 0).toDouble();
          final double courseRevenue = courseStudents * precio;
          
          final Map<String, dynamic> courseWithStats = Map<String, dynamic>.from(row);
          courseWithStats['real_students'] = courseStudents;
          courseWithStats['real_revenue'] = courseRevenue;
          
          courses.add(courseWithStats);
          globalStudents += courseStudents;
          globalRevenue += courseRevenue;
          globalLikes += (row['likes_count'] ?? 0) as int;
          totalV += (row['vistas'] ?? 0) as int;
          
          final double r = (row['rating_promedio'] ?? 0).toDouble();
          if (r > 0) {
            totalRating += r;
            coursesWithRating++;
          }

          // Identificar el curso estrella (Top Course)
          if (courseStudents > maxStudents) {
            maxStudents = courseStudents;
            topCourseCandidate = courseWithStats;
          }
        }

        if (mounted) {
          setState(() {
            _instructorName = profile['nombre_completo'] ?? "Instructor";
            _myCourses = courses;
            _recentActivity = List<Map<String, dynamic>>.from(activityRes);
            _topCourse = topCourseCandidate;
            _totalStudents = globalStudents;
            _totalRevenue = globalRevenue;
            _totalViews = totalV;
            _totalLikes = globalLikes;
            _avgRating = coursesWithRating > 0 ? totalRating / coursesWithRating : 0.0;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardTab(),
          _buildCoursesTab(),
          const InstructorMonitoringScreen(), // <--- Integrado como Tab
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_stories_rounded), label: "Cursos"),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: "Alumnos"),
        ],
      ),
    );
  }

  // --- TAB 1: DASHBOARD ---
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Panel de\nControl", style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B), height: 1.1)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 28, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 32),
          
          // Métrica Principal con Botón de Retiro
          _buildStatCard(
            label: "INGRESOS TOTALES", 
            value: "S/ ${_totalRevenue.toStringAsFixed(2)}", 
            subInfo: "Generado en Aura Academy",
            action: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solicitud de retiro enviada a revisión 💸")));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("RETIRAR", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSmallStatCard("ALUMNOS", "$_totalStudents", Icons.people_rounded, const Color(0xFF6366F1))),
              const SizedBox(width: 16),
              Expanded(child: _buildSmallStatCard("VISTAS", "$_totalViews", Icons.remove_red_eye_rounded, const Color(0xFF2DD4BF))),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatCard(label: "CALIFICACIÓN PROMEDIO", value: _avgRating == 0.0 ? "N/A" : _avgRating.toStringAsFixed(2), subInfo: "Basado en reseñas verificadas", iconValue: const Icon(Icons.star_rounded, color: Colors.amber, size: 28)),
          
          const SizedBox(height: 16),
          _buildStatCard(
            label: "ME GUSTAS TOTALES", 
            value: "$_totalLikes", 
            subInfo: "Reacciones positivas en tus cursos", 
            iconValue: const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 28)
          ),

          // --- SECCIÓN: GRÁFICO DE INGRESOS ---
          const SizedBox(height: 32),
          Text("Ingresos Semanales (S/)", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _buildWeeklyChart(),

          // --- SECCIÓN: RANKING TOP 5 ---
          if (_myCourses.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text("Ranking de Cursos 🏆", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            const SizedBox(height: 16),
            _buildTopCoursesRanking(),
          ],

          const SizedBox(height: 32),
          // --- SECCIÓN: ACTIVIDAD RECIENTE ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Actividad Reciente", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 2), // <--- Salta a la pestaña de Alumnos
                child: const Text("Ver todo", style: TextStyle(color: Color(0xFF6366F1))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_recentActivity.isEmpty)
             _buildEmptyActivity()
          else
            ..._recentActivity.map((activity) => _buildActivityItem(activity)),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    double maxVal = _weeklyRevenue.reduce((curr, next) => curr > next ? curr : next);
    if (maxVal == 0) maxVal = 1.0; // Evitar división por cero

    final days = ["L", "M", "M", "J", "V", "S", "D"];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final heightFactor = _weeklyRevenue[index] / maxVal;
              return Column(
                children: [
                  Container(
                    width: 30,
                    height: 100 * heightFactor + 4, // Altura mínima de 4px
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF6366F1), const Color(0xFF6366F1).withOpacity(0.6)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(days[index], style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                ],
              );
            }),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text("Ingresos por día (S/)", style: GoogleFonts.montserrat(fontSize: 11, color: const Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildTopCoursesRanking() {
    // Ordenar por alumnos y tomar los mejores 5
    final top5 = List<Map<String, dynamic>>.from(_myCourses);
    top5.sort((a, b) => (b['real_students'] as int).compareTo(a['real_students'] as int));
    final displayList = top5.take(5).toList();

    return Column(
      children: displayList.asMap().entries.map((entry) {
        final index = entry.key;
        final course = entry.value;
        final bool isTop = index == 0;
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CourseDetailScreen(courseId: course['id'])),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isTop ? const Color(0xFFFDE68A) : Colors.transparent, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isTop ? const Color(0xFFF59E0B) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: GoogleFonts.montserrat(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: index == 0 ? Colors.white : const Color(0xFF64748B)
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course['titulo'] ?? "", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text("${course['real_students']} alumnos", style: GoogleFonts.montserrat(fontSize: 11, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: Colors.grey[300], size: 40),
            const SizedBox(height: 8),
            Text("Sin actividad nueva", style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final bool isGraduation = activity['tipo'] == 'graduacion';
    final studentName = activity['alumno'] ?? activity['perfiles']?['nombre_completo'] ?? "Alumno";
    final courseTitle = activity['curso'] ?? activity['cursos']?['titulo'] ?? "un curso";
    final String actionText = isGraduation ? " se graduó de " : " se inscribió en ";
    final IconData icon = isGraduation ? Icons.school_rounded : Icons.person_add_alt_1_rounded;
    final Color iconColor = isGraduation ? const Color(0xFFF59E0B) : const Color(0xFF6366F1);
    final Color bgColor = isGraduation ? const Color(0xFFFEF3C7) : const Color(0xFFE8E7FF);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.montserrat(fontSize: 13, color: const Color(0xFF1E293B)),
                    children: [
                      TextSpan(text: studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: actionText),
                      TextSpan(text: courseTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text("Hace un momento", style: GoogleFonts.montserrat(fontSize: 10, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: CURSOS ---
  Widget _buildCoursesTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("Mis Cursos", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCourseScreen())).then((_) => _loadData()),
            icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF6366F1), size: 30),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _myCourses.isEmpty 
          ? _buildEmptyCoursesState()
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _myCourses.length,
              itemBuilder: (context, index) {
                final c = _myCourses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildCourseCard(
                    courseId: c['id'],
                    title: c['titulo'] ?? "Sin título",
                    imageUrl: c['thumbnail_url'] ?? "",
                    students: c['real_students'] ?? 0,
                    revenue: c['real_revenue'] ?? 0,
                    rating: (c['rating_promedio'] ?? 0).toDouble(),
                    status: (c['estado'] ?? 'Borrador').toUpperCase(),
                    views: c['vistas'] ?? 0,
                    likes: c['likes_count'] ?? 0,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyCoursesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off_rounded, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text("No tienes cursos publicados", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCourseScreen())).then((_) => _loadData()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            child: const Text("Crear mi primer curso"),
          ),
        ],
      ),
    );
  }

  // WIDGETS DE APOYO
  Widget _buildStatCard({required String label, required String value, required String subInfo, Widget? iconValue, Widget? action}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: const Color(0xFF94A3B8))),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(value, style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              if (iconValue != null) ...[const SizedBox(width: 8), iconValue],
            ],
          ),
          const SizedBox(height: 8),
          Text(subInfo, style: GoogleFonts.montserrat(fontSize: 12, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          Text(label, style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildCourseCard({required String courseId, required String title, required String imageUrl, required int students, required num revenue, required double rating, required String status, required int views, required int likes}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              children: [
                Image.network(imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 120, color: Colors.grey[100])),
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: status == 'PUBLICADO' ? const Color(0xFFDCFCE7) : Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Text(status, style: TextStyle(color: status == 'PUBLICADO' ? const Color(0xFF166534) : Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(onPressed: () => _showDeleteConfirmation(courseId, title), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF94A3B8), size: 14),
                    const SizedBox(width: 4),
                    Text("$views", style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(width: 12),
                    const Icon(Icons.favorite_rounded, color: Colors.red, size: 12),
                    const SizedBox(width: 4),
                    Text("$likes", style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("S/ $revenue", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1), fontSize: 15)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreateCourseScreen(courseId: courseId))).then((_) => _loadData()),
                      child: const Text("EDITAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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

  void _showDeleteConfirmation(String courseId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Eliminar curso?", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text("¿Estás seguro de que quieres eliminar '$title'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(onPressed: () { Navigator.pop(context); _deleteCourse(courseId); }, child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _deleteCourse(String courseId) async {
    try {
      await supabase.from('cursos').delete().eq('id', courseId);
      _loadData();
    } catch (e) {
      debugPrint("Error al borrar: $e");
    }
  }
}

// Pintor Nativo de Bordes Punteados
class DashedRectPainter extends CustomPainter {
  Color color;
  double strokeWidth;
  double gap;

  DashedRectPainter({this.color = Colors.black, this.strokeWidth = 1.0, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    Paint dashedPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double x = size.width;
    double y = size.height;

    Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, x, y), const Radius.circular(24)));

    Path dashPath = Path();
    double distance = 0;
    bool draw = true;
    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        if (draw) {
          dashPath.addPath(pathMetric.extractPath(distance, distance + gap), Offset.zero);
        }
        distance += gap;
        draw = !draw;
      }
    }
    
    canvas.drawPath(dashPath, dashedPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}





