import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseStructureScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseStructureScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseStructureScreen> createState() => _CourseStructureScreenState();
}

class _CourseStructureScreenState extends State<CourseStructureScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _modules = [];

  @override
  void initState() {
    super.initState();
    _loadStructure();
  }

  Future<void> _loadStructure() async {
    try {
      // 1. Cargar Módulos
      final modulesData = await supabase
          .from('modulos')
          .select('*, lecciones(*)')
          .eq('curso_id', widget.courseId)
          .order('orden', ascending: true);

      setState(() {
        _modules = List<Map<String, dynamic>>.from(modulesData);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando estructura: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addModule({String? moduleId, String? initialTitle}) async {
    final TextEditingController titleController = TextEditingController(text: initialTitle);
    
    // Posicionar cursor al final para evitar selección automática molesta
    titleController.selection = TextSelection.fromPosition(
      TextPosition(offset: titleController.text.length),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(moduleId == null ? "Nuevo Módulo" : "Editar Módulo", 
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: "Ej. Introducción al curso",
            border: UnderlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, titleController.text),
            child: Text(moduleId == null ? "Crear" : "Guardar"),
          ),
        ],
      ),
    ).then((titulo) async {
      if (titulo != null && titulo.toString().isNotEmpty) {
        if (moduleId == null) {
          await supabase.from('modulos').insert({
            'curso_id': widget.courseId,
            'titulo': titulo,
            'orden': _modules.length + 1,
          });
        } else {
          await supabase.from('modulos').update({'titulo': titulo}).eq('id', moduleId);
        }
        _loadStructure();
      }
    });
  }

  Future<void> _deleteModule(String moduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar Módulo?"),
        content: const Text("Se borrarán también todas las lecciones dentro de este módulo."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.from('modulos').delete().eq('id', moduleId);
      _loadStructure();
    }
  }

  Future<void> _addLesson(String moduleId, {String? lessonId, String? initialTitle, String? initialVideo, int? lessonCount}) async {
    final TextEditingController titleController = TextEditingController(text: initialTitle);
    final TextEditingController videoController = TextEditingController(text: initialVideo);

    titleController.selection = TextSelection.fromPosition(TextPosition(offset: titleController.text.length));

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(lessonId == null ? "Nueva Lección" : "Editar Lección", 
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController, 
              decoration: const InputDecoration(hintText: "Título de la clase"), 
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(controller: videoController, decoration: const InputDecoration(hintText: "Link de video (YouTube/Vimeo)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {'titulo': titleController.text, 'video': videoController.text}),
            child: Text(lessonId == null ? "Añadir" : "Guardar"),
          ),
        ],
      ),
    ).then((data) async {
      if (data != null && data['titulo'].toString().isNotEmpty) {
        if (lessonId == null) {
          await supabase.from('lecciones').insert({
            'curso_id': widget.courseId,
            'modulo_id': moduleId,
            'titulo': data['titulo'],
            'video_url': data['video'],
            'orden': (lessonCount ?? 0) + 1,
          });
        } else {
          await supabase.from('lecciones').update({
            'titulo': data['titulo'],
            'video_url': data['video'],
          }).eq('id', lessonId);
        }
        _loadStructure();
      }
    });
  }

  Future<void> _deleteLesson(String lessonId) async {
    await supabase.from('lecciones').delete().eq('id', lessonId);
    _loadStructure();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text("Estructura del Curso", style: GoogleFonts.montserrat(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.courseTitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: _modules.isEmpty 
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _modules.length,
                      itemBuilder: (context, index) {
                        final modulo = _modules[index];
                        final lessons = List<Map<String, dynamic>>.from(modulo['lecciones'] ?? []);
                        return _buildModuleItem(modulo, lessons);
                      },
                    ),
              ),
              _buildBottomAction(),
            ],
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_rounded, size: 80, color: const Color(0xFF6366F1).withOpacity(0.2)),
          const SizedBox(height: 24),
          Text("Tu temario está vacío", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const SizedBox(height: 8),
          const Text("Empieza creando tu primer módulo", style: TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildModuleItem(Map<String, dynamic> modulo, List<Map<String, dynamic>> lessons) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.folder_open_rounded, color: Color(0xFF6366F1), size: 18),
          ),
          title: Text(modulo['titulo'], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), fontSize: 15)),
          subtitle: Text("${lessons.length} lecciones", style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          trailing: PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text("Editar Módulo")),
              const PopupMenuItem(value: 'delete', child: Text("Eliminar", style: TextStyle(color: Colors.red))),
            ],
            onSelected: (value) {
              if (value == 'edit') {
                _addModule(moduleId: modulo['id'], initialTitle: modulo['titulo']);
              } else if (value == 'delete') {
                _deleteModule(modulo['id']);
              }
            },
          ),
          children: [
            const Divider(height: 1),
            ...lessons.map((lesson) => _buildLessonItem(modulo['id'], lesson)).toList(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: () => _addLesson(modulo['id'], lessonCount: lessons.length),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text("Añadir Lección"),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonItem(String moduleId, Map<String, dynamic> lesson) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF94A3B8), size: 20),
      title: Text(lesson['titulo'], style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
      trailing: PopupMenuButton(
        icon: const Icon(Icons.more_horiz, size: 18, color: Color(0xFFCBD5E1)),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text("Editar Lección")),
          const PopupMenuItem(value: 'delete', child: Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
        onSelected: (value) {
          if (value == 'edit') {
            _addLesson(
              moduleId, 
              lessonId: lesson['id'], 
              initialTitle: lesson['titulo'], 
              initialVideo: lesson['video_url']
            );
          } else if (value == 'delete') {
            _deleteLesson(lesson['id']);
          }
        },
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: _addModule,
          icon: const Icon(Icons.add),
          label: const Text("Añadir Nuevo Módulo"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }
}
