import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_academy/screens/instructor/create_course_screen.dart';
import 'package:aura_academy/screens/courses/lesson_player_screen.dart';
import 'package:aura_academy/screens/dashboard/dashboard_screen.dart'; // <--- Para el controlador global

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
  bool _isEnrolled = false;
  bool _isInWishlist = false;
  String? _wishlistId;
  List<String> _completedLessonIds = [];
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _myReview;
  int? _selectedStarFilter;
  bool _sortNewestFirst = true;

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    try {
      debugPrint("🔍 Intentando cargar curso ID: ${widget.courseId}");
      
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

      // 3. Verificar Inscripción si no es el instructor
      final userId = supabase.auth.currentUser?.id;
      bool enrolled = false;
      if (userId != null && courseData['instructor_id'] != userId) {
        final enrollment = await supabase
            .from('inscripciones')
            .select()
            .eq('perfil_id', userId)
            .eq('curso_id', widget.courseId)
            .maybeSingle();
        enrolled = enrollment != null;
      }

      // 4. Verificar Lista de Deseos
      bool inWishlist = false;
      String? wishId;
      if (userId != null) {
        final wishlistRes = await supabase
            .from('lista_deseos')
            .select()
            .eq('perfil_id', userId)
            .eq('curso_id', widget.courseId)
            .maybeSingle();
        
        if (wishlistRes != null) {
          inWishlist = true;
          wishId = wishlistRes['id'];
        }
      }

      List<String> completedIds = [];
      if (userId != null) {
        final completedRes = await supabase
            .from('lecciones_completadas')
            .select('leccion_id')
            .eq('perfil_id', userId)
            .eq('curso_id', widget.courseId);
        completedIds = (completedRes as List).map((c) => c['leccion_id'].toString()).toList();
      }

      // 5. Cargar Reseñas
      final reviewsRes = await supabase
          .from('resenas')
          .select('*, perfiles(nombre_completo)')
          .eq('curso_id', widget.courseId)
          .order('fecha', ascending: false);
          
      final reviews = List<Map<String, dynamic>>.from(reviewsRes);
      Map<String, dynamic>? myRev;
      if (userId != null) {
        try {
          myRev = reviews.firstWhere((r) => r['perfil_id'] == userId);
        } catch (_) {}
      }

      setState(() {
        _course = courseData;
        _modules = List<Map<String, dynamic>>.from(modulesData);
        _isInstructor = courseData['instructor_id'] == userId;
        _isEnrolled = enrolled;
        _isInWishlist = inWishlist;
        _wishlistId = wishId;
        _completedLessonIds = completedIds;
        _reviews = reviews;
        _myReview = myRev;
        _isLoading = false;
      });

      // Incrementar vistas usando la función de Vistas Únicas (RPC)
      final instructorId = courseData['instructor_id'];
      
      if (userId != null && userId != instructorId) {
        try {
          await supabase.rpc('incrementar_vistas_curso', params: {
            'id_curso': widget.courseId,
            'id_usuario': userId
          });
          DashboardScreen.courseUpdateController.add(null);
        } catch (e) {
          debugPrint("Error al registrar vista única: $e");
        }
      }
    } catch (e) {
      debugPrint("❌ ERROR CRÍTICO EN DETALLE: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enrollInCourse() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Diálogo de Confirmación "Premium"
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Icon(Icons.shopping_cart_checkout_rounded, size: 48, color: Color(0xFF6366F1)),
            const SizedBox(height: 16),
            Text("Confirmar Compra", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Estás a punto de adquirir:",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _course!['titulo'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total a Pagar:", style: TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    "S/ ${_course!['precio']}", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF6366F1))
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.all(20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Pagar y Desbloquear", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await supabase.from('inscripciones').insert({
        'perfil_id': userId,
        'curso_id': widget.courseId,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Compra exitosa! Bienvenido al curso 🎉"),
            backgroundColor: Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadCourseDetails();
    } catch (e) {
      debugPrint("Error al inscribirse: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleWishlist() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // BLOQUEO DE AUTO-LIKE (Instructor no puede darse like a sí mismo)
    if (_isInstructor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("👨‍🏫 ¡Eres el instructor! No puedes darte auto-like a tu propio curso."),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
      return;
    }

    try {
      if (_isInWishlist) {
        // Eliminar
        if (_wishlistId != null) {
          await supabase.from('lista_deseos').delete().eq('id', _wishlistId!);
          
          setState(() {
            _isInWishlist = false;
            _wishlistId = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Eliminado de tu lista de deseos 💔")),
            );
          }
        }
      } else {
        // Agregar
        final res = await supabase.from('lista_deseos').insert({
          'perfil_id': userId,
          'curso_id': widget.courseId,
        }).select().single();

        setState(() {
          _isInWishlist = true;
          _wishlistId = res['id'];
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("¡Agregado a tu lista de deseos! 💖"),
              backgroundColor: Color(0xFFF43F5E),
            ),
          );
        }
      }
      
      // NOTIFICAR ACTUALIZACIÓN GLOBAL
      DashboardScreen.courseUpdateController.add(null);
      // Recargar detalles locales para ver el nuevo conteo de likes si lo mostramos
      _loadCourseDetails();
      
    } catch (e) {
      debugPrint("Error en wishlist: $e");
    }
  }

  Future<void> _submitRating(int rating, String comment) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      setState(() => _isLoading = true);
      // Actualizar o Insertar usando upsert
      await supabase.from('resenas').upsert({
        if (_myReview != null) 'id': _myReview!['id'],
        'curso_id': widget.courseId,
        'perfil_id': userId,
        'estrellas': rating,
        'comentario': comment.trim().isEmpty ? null : comment.trim(),
      });
      
      // La base de datos actualiza el rating con el trigger
      // Recargamos
      _loadCourseDetails();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Gracias por tu reseña! 🌟"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error al enviar reseña: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al enviar reseña"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRatingModal() {
    int selectedRating = _myReview != null ? (_myReview!['estrellas'] as num).toInt() : 5;
    TextEditingController commentController = TextEditingController(text: _myReview?['comentario'] ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _myReview == null ? "Califica este curso" : "Actualiza tu reseña", 
                    style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () {
                          setModalState(() => selectedRating = index + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "¿Qué te pareció el curso? (Opcional)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _submitRating(selectedRating, commentController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: const Text("Enviar Reseña", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // ELIMINADO EL BLOQUEO TOTAL DE CARGA
    // Ahora la pantalla se abre de inmediato

    if (_course == null) {
      if (_isLoading) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          ),
        );
      }
      return const Scaffold(body: Center(child: Text("No se encontró el curso")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: const Color(0xFF6366F1),
        onRefresh: _loadCourseDetails,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    const SizedBox(height: 32),
                    _buildReviewsSection(),
                    const SizedBox(height: 120), // Espacio para el botón flotante
                  ],
                ),
              ),
            ),
          ],
        ),
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
      actions: [
        IconButton(
          icon: Icon(
            _isInWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
            color: _isInWishlist ? const Color(0xFFF43F5E) : Colors.white,
          ),
          onPressed: _toggleWishlist,
        ),
        const SizedBox(width: 8),
      ],
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
        const SizedBox(height: 16),
        // Duración
        if (_course!['duracion_texto'] != null && _course!['duracion_texto'].toString().isNotEmpty)
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                _course!['duracion_texto'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
              ),
            ],
          ),
        const SizedBox(height: 24),
        // Descripción detallada
        if (_course!['descripcion'] != null && _course!['descripcion'].toString().isNotEmpty) ...[
          Text(
            "Acerca de este curso",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            _course!['descripcion'],
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.6),
          ),
          const SizedBox(height: 24),
        ],
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
    final bool hasAccess = _isInstructor || _isEnrolled;
    final bool isCompleted = _completedLessonIds.contains(lesson['id'].toString());
    
    return ListTile(
      onTap: () async {
        if (hasAccess) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonPlayerScreen(
                courseId: widget.courseId, 
                initialLessonId: lesson['id'].toString()
              ),
            ),
          );
          // Recargar detalles al volver por si completó lecciones
          _loadCourseDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Inscríbete para ver esta clase 🔒")),
          );
        }
      },
      leading: Icon(
        hasAccess ? Icons.play_circle_fill : Icons.play_circle_outline, 
        color: hasAccess ? const Color(0xFF6366F1) : const Color(0xFF94A3B8), 
        size: 20
      ),
      title: Text(
        lesson['titulo'], 
        style: TextStyle(
          fontSize: 14, 
          color: hasAccess ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)
        )
      ),
      trailing: hasAccess 
        ? (isCompleted 
            ? const Icon(Icons.check_circle, size: 18, color: Colors.green)
            : const SizedBox(width: 16, height: 16))
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

  Widget _buildReviewsSection() {
    final Map<int, int> starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (var r in _reviews) {
      final stars = (r['estrellas'] as num?)?.toInt() ?? 5;
      if (starCounts.containsKey(stars)) {
        starCounts[stars] = starCounts[stars]! + 1;
      }
    }

    final totalCount = _reviews.length;

    // Filtrar reseñas
    final List<Map<String, dynamic>> filteredReviews = _selectedStarFilter == null
        ? List<Map<String, dynamic>>.from(_reviews)
        : List<Map<String, dynamic>>.from(_reviews.where((r) => (r['estrellas'] as num).toInt() == _selectedStarFilter));

    // Ordenar reseñas por fecha
    filteredReviews.sort((a, b) {
      final aDate = DateTime.parse(a['fecha'] ?? DateTime.now().toString());
      final bDate = DateTime.parse(b['fecha'] ?? DateTime.now().toString());
      return _sortNewestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Opiniones de los estudiantes",
                style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
            ),
            // Solo estudiantes matriculados pueden calificar, el instructor no puede opinar sobre su propio curso
            if (_isEnrolled)
              TextButton.icon(
                onPressed: _showRatingModal,
                icon: const Icon(Icons.star_rounded, color: Colors.amber),
                label: Text(_myReview == null ? "Calificar" : "Editar", style: const TextStyle(fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_reviews.isNotEmpty) ...[
          // Gráfico de barras de distribución
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Text(
                  "Distribución de calificaciones",
                  style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                ...List.generate(5, (index) {
                  final star = 5 - index;
                  final count = starCounts[star] ?? 0;
                  final percentage = totalCount > 0 ? count / totalCount : 0.0;
                  final isSelected = _selectedStarFilter == star;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStarFilter = isSelected ? null : star;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.star_rounded,
                            color: isSelected ? Colors.green : Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 80,
                            child: Text(
                              "$star estrellas",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.green : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFE2E8F0),
                                color: isSelected ? Colors.green : const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 30,
                            child: Text(
                              "$count",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.green : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedStarFilter != null 
                    ? "Filtrando: $_selectedStarFilter estrellas" 
                    : "Mostrando todas las opiniones",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              DropdownButton<bool>(
                value: _sortNewestFirst,
                underline: const SizedBox(),
                icon: const Icon(Icons.sort_rounded, size: 16, color: Color(0xFF6366F1)),
                style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: true, child: Text("Más recientes")),
                  DropdownMenuItem(value: false, child: Text("Más antiguas")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _sortNewestFirst = val);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Botón para borrar filtro
          if (_selectedStarFilter != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Filtro por estrellas activo",
                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedStarFilter = null),
                  child: const Text("Mostrar todas"),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (filteredReviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _selectedStarFilter != null
                    ? "No hay opiniones de $_selectedStarFilter estrellas para este curso."
                    : "Aún no hay reseñas para este curso.\n¡Sé el primero en calificarlo!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredReviews.length,
            separatorBuilder: (context, index) => const Divider(height: 32),
            itemBuilder: (context, index) {
              final r = filteredReviews[index];
              final String studentName = r['perfiles']?['nombre_completo'] ?? 'Estudiante';
              final int stars = (r['estrellas'] as num).toInt();
              final String? comment = r['comentario'];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                        child: Text(studentName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Row(
                        children: List.generate(5, (starIdx) => Icon(
                          starIdx < stars ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 16,
                        )),
                      ),
                    ],
                  ),
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(comment, style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5)),
                  ]
                ],
              );
            },
          ),
      ],
    );
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
                if (!_isEnrolled && !_isInstructor) ...[
                  const Text(
                    "PRECIO TOTAL", 
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)
                  ),
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
                ] else ...[
                  Text(
                    _isInstructor ? "MODO INSTRUCTOR" : "YA ERES ESTUDIANTE", 
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Acceso completo",
                    style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1))
                  ),
                ],
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
                  } else if (!_isEnrolled) {
                    _enrollInCourse();
                  } else {
                    // Acción para continuar viendo el curso
                    if (_modules.isNotEmpty && (_modules.first['lecciones'] as List).isNotEmpty) {
                      final firstLessonId = _modules.first['lecciones'][0]['id'];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LessonPlayerScreen(
                            courseId: widget.courseId, 
                            initialLessonId: firstLessonId
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Este curso aún no tiene lecciones. 😅")),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isInstructor 
                    ? "Gestionar Curso" 
                    : (_isEnrolled ? "Continuar Aprendiendo" : "Comprar Ahora"), 
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





