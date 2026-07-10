import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

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
          .select('*, lecciones(*, recursos_leccion(*))')
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(moduleId == null ? "Nuevo Módulo" : "Editar Módulo", 
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("NOMBRE DEL MÓDULO", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: "Ej. Introducción",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.all(20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, titleController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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

    bool isUploading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text(lessonId == null ? "Nueva Lección" : "Editar Lección", 
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TÍTULO DE LA CLASE", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                  child: TextField(
                    controller: titleController, 
                    decoration: const InputDecoration(hintText: "Ej. Instalación de VS Code", border: InputBorder.none), 
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(height: 20),
                Text("LINK O ARCHIVO DEL VIDEO", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                        child: TextField(
                          controller: videoController, 
                          decoration: const InputDecoration(hintText: "YouTube, Vimeo URL, o sube uno", border: InputBorder.none)
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: isUploading ? null : () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
                          if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
                            setState(() => isUploading = true);
                            
                            final fileExt = result.files.first.extension ?? 'mp4';
                            final fileName = 'lesson_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
                            final filePath = '${widget.courseId}/$moduleId/$fileName';

                            await supabase.storage.from('recursos').uploadBinary(
                              filePath,
                              result.files.first.bytes!,
                              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
                            );

                            final String publicUrl = supabase.storage.from('recursos').getPublicUrl(filePath);
                            setState(() {
                              videoController.text = publicUrl;
                              isUploading = false;
                            });
                          }
                        } catch (e) {
                          setState(() => isUploading = false);
                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al subir video: $e")));
                        }
                      },
                      icon: isUploading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.upload_file_rounded),
                      tooltip: "Subir video desde PC",
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEEF2FF),
                        foregroundColor: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.all(20),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(context), 
                child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton(
                onPressed: isUploading ? null : () => Navigator.pop(context, {'titulo': titleController.text, 'video': videoController.text}),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(lessonId == null ? "Añadir" : "Guardar"),
              ),
            ],
          );
        }
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

  Future<void> _uploadResource(String lessonId) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      
      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileExt = fileName.split('.').last;
        final filePath = '${widget.courseId}/$lessonId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        // 1. Subir al Storage
        await supabase.storage.from('recursos').upload(filePath, file);

        // 2. Obtener URL pública
        final publicUrl = supabase.storage.from('recursos').getPublicUrl(filePath);

        // 3. Registrar en la tabla
        await supabase.from('recursos_leccion').insert({
          'leccion_id': lessonId,
          'nombre': fileName,
          'archivo_url': publicUrl,
          'tipo': fileExt.toUpperCase(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Archivo '$fileName' subido con éxito! 📎")),
          );
        }
        _loadStructure();
      }
    } catch (e) {
      debugPrint("Error subiendo recurso: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al subir archivo: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteResource(String resourceId) async {
    await supabase.from('recursos_leccion').delete().eq('id', resourceId);
    _loadStructure();
  }

  void _showActionMenu({
    required String title,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Text(
              title.toUpperCase(),
              style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.edit_rounded, color: Color(0xFF6366F1), size: 20),
              ),
              title: const Text("Editar Información", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
              ),
              title: const Text("Eliminar Registro", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
          trailing: IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
            onPressed: () => _showActionMenu(
              title: "Opciones de Módulo",
              onEdit: () => _addModule(moduleId: modulo['id'], initialTitle: modulo['titulo']),
              onDelete: () => _deleteModule(modulo['id']),
            ),
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
    final recursos = List<Map<String, dynamic>>.from(lesson['recursos_leccion'] ?? []);
    
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          leading: const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF94A3B8), size: 20),
          title: Text(lesson['titulo'], style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recursos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Text("${recursos.length} 📎", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              IconButton(
                icon: const Icon(Icons.attach_file_rounded, size: 18, color: Color(0xFF6366F1)),
                onPressed: () => _uploadResource(lesson['id']),
                tooltip: "Adjuntar material",
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, size: 18, color: Color(0xFFCBD5E1)),
                onPressed: () => _showActionMenu(
                  title: "Opciones de Lección",
                  onEdit: () => _addLesson(
                    moduleId, 
                    lessonId: lesson['id'], 
                    initialTitle: lesson['titulo'], 
                    initialVideo: lesson['video_url']
                  ),
                  onDelete: () => _deleteLesson(lesson['id']),
                ),
              ),
            ],
          ),
        ),
        if (recursos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 64, right: 24, bottom: 8),
            child: Column(
              children: recursos.map((res) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(res['nombre'], style: const TextStyle(fontSize: 11, color: Colors.grey))),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.red),
                      onPressed: () => _deleteResource(res['id']),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              )).toList(),
            ),
          )
      ],
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






