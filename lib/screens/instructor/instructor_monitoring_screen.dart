import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_academy/screens/instructor/course_students_screen.dart';

class InstructorMonitoringScreen extends StatefulWidget {
  const InstructorMonitoringScreen({super.key});

  @override
  State<InstructorMonitoringScreen> createState() => _InstructorMonitoringScreenState();
}

class _InstructorMonitoringScreenState extends State<InstructorMonitoringScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _myCourses = [];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Obtener cursos con los IDs de inscripciones para contar excluyendo al instructor
      final results = await supabase
          .from('cursos')
          .select('id, titulo, thumbnail_url, instructor_id, inscripciones(perfil_id)')
          .eq('instructor_id', user.id);

      setState(() {
        _myCourses = List<Map<String, dynamic>>.from(results);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando monitoreo: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Monitoreo de Cursos",
          style: GoogleFonts.montserrat(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF64748B)),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _myCourses.isEmpty
              ? _buildEmptyState()
              : _buildCourseList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.class_outlined, size: 80, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text("No has creado cursos aún", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 8),
          const Text("Crea tu primer curso para empezar\na monitorear a tus alumnos.", textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _myCourses.length,
      itemBuilder: (context, index) {
        final course = _myCourses[index];
        final List inscripciones = course['inscripciones'] ?? [];
        // Filtrar para no contar al instructor si se inscribió a su propio curso
        final int studentCount = inscripciones.where((i) => i['perfil_id'] != course['instructor_id']).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CourseStudentsScreen(
                    courseId: course['id'],
                    courseTitle: course['titulo'],
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      course['thumbnail_url'] ?? 'https://via.placeholder.com/150',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course['titulo'],
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$studentCount ${studentCount == 1 ? 'estudiante inscrito' : 'estudiantes inscritos'}",
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}





