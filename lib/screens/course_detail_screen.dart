import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_course_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _course;
  List<Map<String, dynamic>> _modules = [];
  bool _isInstructor = false;

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    try {
      // 1. Cargar info del curso + Instructor
      final courseData = await supabase
          .from('cursos')
          .select('*, perfiles(nombre_completo)')
          .eq('id', widget.courseId)
          .single();

      // 2. Cargar Módulos y sus Lecciones
      final modulesData = await supabase
          .from('modulos')
          .select('*, lecciones(*)')
          .eq('curso_id', widget.courseId)
          .order('orden', ascending: true);

      // Ordenar lecciones dentro de cada módulo
      for (var mod in modulesData) {
        if (mod['lecciones'] != null) {
          (mod['lecciones'] as List).sort((a, b) => (a['orden'] ?? 0).compareTo(b['orden'] ?? 0));
        }
      }

      setState(() {
        _course = courseData;
        _modules = List<Map<String, dynamic>>.from(modulesData);
        _isInstructor = courseData['instructor_id'] == supabase.auth.currentUser?.id;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando detalle del curso: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_course == null) {
      return const Scaffold(body: Center(child: Text("No se encontró el curso")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(),
                  const SizedBox(height: 32),
                  _buildCurriculum(),
                  const SizedBox(height: 100), // Espacio para el botón flotante
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomCTA(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: const Color(0xFF6366F1),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _course!['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=800',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    final instructor = _course!['perfiles']?['nombre_completo'] ?? "Instructor de Aura";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            (_course!['nivel'] ?? 'Todos los niveles').toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6366F1),
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _course!['titulo'] ?? "Sin Título",
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _course!['subtitulo'] ?? "",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1E293B),
              child: Text(instructor[0], style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Creado por", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                Text(instructor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurriculum() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Contenido del Curso",
          style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        Text("${_modules.length} módulos • ${_getTotalLessons()} lecciones", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _modules.length,
          itemBuilder: (context, index) {
            final mod = _modules[index];
            final lessons = mod['lecciones'] as List? ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                title: Text(
                  mod['titulo'],
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B)),
                ),
                subtitle: Text("${lessons.length} clases", style: const TextStyle(fontSize: 12)),
                children: lessons.map((lesson) => _buildLessonTile(lesson)).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLessonTile(Map<String, dynamic> lesson) {
    return ListTile(
      leading: const Icon(Icons.play_circle_outline, color: Color(0xFF6366F1), size: 20),
      title: Text(lesson['titulo'], style: const TextStyle(fontSize: 14)),
      trailing: _isInstructor 
        ? const Icon(Icons.play_circle_fill, size: 16, color: Color(0xFF6366F1))
        : const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
    );
  }

  int _getTotalLessons() {
    int total = 0;
    for (var m in _modules) {
      total += (m['lecciones'] as List? ?? []).length;
    }
    return total;
  }

  Widget _buildBottomCTA() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isInstructor ? "MODO INSTRUCTOR" : "PRECIO TOTAL", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text("S/ ${_course!['precio']}", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                      if (_course!['en_oferta'] == true) ...[
                        const SizedBox(width: 6),
                        Text(
                          "S/ ${_course!['precio_original']}",
                          style: const TextStyle(fontSize: 13, color: Colors.grey, decoration: TextDecoration.lineThrough),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: _isInstructor 
                    ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                    : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (_isInstructor) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateCourseScreen(courseId: widget.courseId),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isInstructor ? "Gestionar Curso" : "Comprar Ahora", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
