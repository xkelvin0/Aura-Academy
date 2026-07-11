import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aura_academy/widgets/aura_chat_widget.dart';
import 'package:aura_academy/screens/certificates/graduation_celebration_screen.dart';

class LessonPlayerScreen extends StatefulWidget {
  final String courseId;
  final String initialLessonId;

  const LessonPlayerScreen({super.key, required this.courseId, required this.initialLessonId});

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _course;
  Map<String, dynamic>? _currentLesson;
  List<dynamic> _modules = [];
  List<dynamic> _currentResources = [];
  bool _isLoading = true;
  bool _isEnrolled = false;
  bool _isInstructor = false;
  bool _isCompleted = false;
  List<String> _completedLessonIds = [];
  
  final _audioPlayer = AudioPlayer();
  YoutubePlayerController? _ytController;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // NUEVAS VARIABLES PARA CONTROL DE REPRODUCCIÓN Y MARCADORES
  double _currentSpeed = 1.0;
  final List<double> _availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  List<Map<String, dynamic>> _lessonNotes = [];
  final TextEditingController _noteTextController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadAllData(widget.initialLessonId);
  }

  @override
  void dispose() {
    _ytController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _audioPlayer.dispose();
    _confettiController.dispose();
    _pulseController.dispose();
    _noteTextController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData(String lessonId) async {
    if (_course == null) {
      setState(() => _isLoading = true);
    }
    
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final courseData = await supabase.from('cursos').select().eq('id', widget.courseId).single();
      _course = courseData;
      _isInstructor = courseData['instructor_id'] == user.id;

      final enrollRes = await supabase
          .from('inscripciones')
          .select()
          .eq('curso_id', widget.courseId)
          .eq('perfil_id', user.id)
          .maybeSingle();
      _isEnrolled = enrollRes != null;

      final modulesRes = await supabase
          .from('modulos')
          .select('*, lecciones(*)')
          .eq('curso_id', widget.courseId)
          .order('orden', ascending: true);
      _modules = modulesRes;

      final completedRes = await supabase
          .from('lecciones_completadas')
          .select('leccion_id')
          .eq('perfil_id', user.id)
          .eq('curso_id', widget.courseId);
      
      _completedLessonIds = (completedRes as List).map((c) => c['leccion_id'].toString()).toList();
      _isCompleted = _completedLessonIds.contains(lessonId);

      final lessonData = await supabase.from('lecciones').select().eq('id', lessonId).single();
      _currentLesson = lessonData;

      final resourcesRes = await supabase.from('recursos_leccion').select().eq('leccion_id', lessonId);
      _currentResources = resourcesRes;

      _ytController?.dispose();
      _ytController = null;
      _chewieController?.dispose();
      _chewieController = null;
      _videoPlayerController?.dispose();
      _videoPlayerController = null;

      // Reiniciar velocidad de reproducción al cambiar de lección
      _currentSpeed = 1.0;

      // Cargar marcadores/notas de esta lección
      try {
        final notesRes = await supabase
            .from('notas_leccion')
            .select()
            .eq('perfil_id', user.id)
            .eq('leccion_id', lessonId)
            .order('segundo', ascending: true);
        _lessonNotes = List<Map<String, dynamic>>.from(notesRes);
      } catch (noteErr) {
        debugPrint("Error cargando notas: $noteErr");
        _lessonNotes = [];
      }

      if (lessonData['video_url'] != null && lessonData['video_url'].toString().isNotEmpty) {
        String videoUrl = lessonData['video_url'].toString();
        if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
          final videoId = YoutubePlayer.convertUrlToId(videoUrl);
          if (videoId != null) {
            _ytController = YoutubePlayerController(
              initialVideoId: videoId,
              flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
            );
          }
        } else if (videoUrl.endsWith('.mp4')) {
          _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
          await _videoPlayerController!.initialize();
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            autoPlay: false,
            looping: false,
            // Permitir cambiar la velocidad en la UI nativa de Chewie si está disponible
            allowPlaybackSpeedChanging: true,
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error interno: $e")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleCompletion([String? lessonId]) async {
    final user = supabase.auth.currentUser;
    final targetLessonId = lessonId ?? _currentLesson?['id'];
    if (user == null || targetLessonId == null) return;

    final bool isAlreadyCompleted = _completedLessonIds.contains(targetLessonId.toString());

    try {
      if (isAlreadyCompleted) {
        await supabase
            .from('lecciones_completadas')
            .delete()
            .eq('perfil_id', user.id)
            .eq('leccion_id', targetLessonId);
            
        setState(() {
          _completedLessonIds.remove(targetLessonId.toString());
          if (targetLessonId == _currentLesson?['id']) _isCompleted = false;
        });
      } else {
        await supabase.from('lecciones_completadas').insert({
          'perfil_id': user.id,
          'curso_id': widget.courseId,
          'leccion_id': targetLessonId,
        });
        
        setState(() {
          _completedLessonIds.add(targetLessonId.toString());
          if (targetLessonId == _currentLesson?['id']) _isCompleted = true;
        });

        try {
          await _audioPlayer.play(AssetSource('audio/lesson_completed.mp3'));
        } catch (e) {
          debugPrint("Error audio: $e");
        }

      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Widget _buildVideoPlayer() {
    if (_ytController != null) {
      return YoutubePlayer(
        key: ValueKey(_ytController!.initialVideoId),
        controller: _ytController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF6366F1),
      );
    } else if (_chewieController != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Chewie(controller: _chewieController!),
      );
    } else {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: const Center(
            child: Text("Sin video disponible", style: TextStyle(color: Colors.white)),
          ),
        ),
      );
    }
  }

  Widget _buildCurriculumList() {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: _modules.length,
      itemBuilder: (context, index) {
        final mod = _modules[index];
        final lessons = List<Map<String, dynamic>>.from(mod['lecciones'] ?? []);
        lessons.sort((a, b) => (a['orden'] ?? 0).compareTo(b['orden'] ?? 0));
        
        return ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            mod['titulo'],
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          children: lessons.map((l) {
            final isPlaying = _currentLesson?['id'] == l['id'];
            final isCompleted = _completedLessonIds.contains(l['id'].toString());
            return ListTile(
              leading: InkWell(
                onTap: () => _toggleCompletion(l['id'].toString()),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFF6366F1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isCompleted ? const Color(0xFF6366F1) : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              title: Text(
                l['titulo'],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                  color: isPlaying ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_outline,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Video",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              onTap: () => _loadAllData(l['id'].toString()),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildResourcesList() {
    if (_currentResources.isEmpty) {
      return const Center(
        child: Text("No hay recursos adicionales en esta lección.", style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _currentResources.length,
      itemBuilder: (context, index) {
        final res = _currentResources[index];
        return Card(
          elevation: 0,
          color: Colors.grey.shade50,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file, color: Color(0xFF6366F1)),
            title: Text(res['titulo']),
            trailing: const Icon(Icons.download, color: Colors.grey),
            onTap: () async {
              final url = res['archivo_url'];
              if (url != null && await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // NUEVAS MEJORAS: CONTROLES DE VELOCIDAD, PIP Y NOTAS/MARCADORES
  // -------------------------------------------------------------

  // Barra de Controles Personalizados
  Widget _buildCustomVideoControls() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Control de Velocidad
          Row(
            children: [
              const Icon(Icons.speed_rounded, size: 20, color: Color(0xFF6366F1)),
              const SizedBox(width: 6),
              DropdownButton<double>(
                value: _currentSpeed,
                underline: const SizedBox(),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                items: _availableSpeeds.map((speed) {
                  return DropdownMenuItem<double>(
                    value: speed,
                    child: Text("${speed}x"),
                  );
                }).toList(),
                onChanged: (newSpeed) {
                  if (newSpeed == null) return;
                  setState(() {
                    _currentSpeed = newSpeed;
                  });
                  // Aplicar a los reproductores correspondientes
                  if (_videoPlayerController != null) {
                    _videoPlayerController!.setPlaybackSpeed(newSpeed);
                  }
                },
              ),
            ],
          ),
          // Botón de Añadir Nota/Marcador
          ElevatedButton.icon(
            onPressed: _showAddNoteDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.bookmark_add_rounded, size: 16),
            label: Text(
              "Guardar Nota",
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Diálogo para guardar nota
  void _showAddNoteDialog() async {
    double currentSecond = 0.0;
    if (_videoPlayerController != null) {
      currentSecond = _videoPlayerController!.value.position.inMilliseconds / 1000.0;
    }

    _noteTextController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.bookmark_rounded, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                "Nueva Nota (${_formatSecondToTime(currentSecond.toInt())})",
                style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: TextField(
            controller: _noteTextController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Escribe un recordatorio o apunte de este segundo...",
              hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancelar", style: GoogleFonts.outfit(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => _saveNote(currentSecond),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text("Guardar", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Guardar la nota en Supabase y refrescar
  Future<void> _saveNote(double second) async {
    final noteText = _noteTextController.text.trim();
    if (noteText.isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null || _currentLesson == null) return;

    Navigator.pop(context); // Cerrar diálogo

    try {
      final newNote = {
        'perfil_id': user.id,
        'leccion_id': _currentLesson!['id'],
        'segundo': second,
        'nota': noteText,
        'fecha_creacion': DateTime.now().toIso8601String(),
      };

      final inserted = await supabase.from('notas_leccion').insert(newNote).select().single();

      setState(() {
        _lessonNotes.add(inserted);
        // Ordenar notas por timestamp
        _lessonNotes.sort((a, b) => ((a['segundo'] ?? 0.0) as double).compareTo((b['segundo'] ?? 0.0) as double));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nota guardada correctamente. 📝"),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
    } catch (e) {
      debugPrint("Error guardando nota: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Eliminar una nota
  Future<void> _deleteNote(String noteId) async {
    try {
      await supabase.from('notas_leccion').delete().eq('id', noteId);
      setState(() {
        _lessonNotes.removeWhere((note) => note['id'].toString() == noteId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nota eliminada. 🗑️"),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
    } catch (e) {
      debugPrint("Error eliminando nota: $e");
    }
  }

  // Saltar a un segundo del video
  void _seekToSecond(double second) {
    if (_videoPlayerController != null) {
      _videoPlayerController!.seekTo(Duration(milliseconds: (second * 1000).toInt()));
    }
  }

  // Formato para mostrar el tiempo del video (ej. 01:24)
  String _formatSecondToTime(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    
    final String minutesStr = m.toString().padLeft(2, '0');
    final String secondsStr = s.toString().padLeft(2, '0');
    
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}:$minutesStr:$secondsStr";
    }
    return "$minutesStr:$secondsStr";
  }

  // Pestaña de Notas/Marcadores
  Widget _buildNotesTab() {
    if (_lessonNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              "No tienes notas en esta lección.",
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              "Toca 'Guardar Nota' en los controles de reproducción.",
              style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: _lessonNotes.length,
      itemBuilder: (context, index) {
        final note = _lessonNotes[index];
        final double second = (note['segundo'] ?? 0.0) as double;

        return Card(
          elevation: 0,
          color: const Color(0xFFF8FAFC),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botón para saltar al segundo
                    InkWell(
                      onTap: () => _seekToSecond(second),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Color(0xFF6366F1), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _formatSecondToTime(second.toInt()),
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF6366F1),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Botón de eliminar nota
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      onPressed: () => _deleteNote(note['id'].toString()),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  note['nota'] ?? "",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E293B),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Abre el modal de Chat Tutor contextualizado
  void _openTutorChat() {
    final String courseTitle = _course?['titulo'] ?? "Curso";
    final String lessonTitle = _currentLesson?['titulo'] ?? "Lección";
    final String lessonDesc = _currentLesson?['descripcion'] ?? "Sin descripción";

    // Creamos un system prompt personalizado que contextualiza a la IA
    final String tutorPrompt = '''
Eres un tutor experto asignado al estudiante en Aura Academy.
Tu objetivo es resolver dudas sobre el curso "$courseTitle".
Actualmente, el estudiante está viendo la clase llamada "$lessonTitle".
Descripción de la lección actual: "$lessonDesc".

Instrucciones:
1. Responde preguntas teóricas, explica fragmentos de código, corrige errores y da ejemplos didácticos sobre el tema del curso y la clase actual.
2. NUNCA ejecutes ni expongas acciones en este chat ([ACTION:...]). Este chat es meramente para tutorías académicas y explicaciones.
3. Sé motivador, conciso y responde siempre en español.
''';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AnimatedPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.80,
            child: AuraChatWidget(
              customSystemPrompt: tutorPrompt,
            ),
          ),
        );
      },
    );
  }

  void _triggerGraduation() {
    _confettiController.play();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GraduationCelebrationScreen(
              courseId: widget.courseId,
              courseTitle: _course?['titulo'] ?? "Curso",
            ),
          ),
        );
      }
    });
  }

  Widget _buildBottomControl() {
    int totalLessons = 0;
    for (var m in _modules) {
      totalLessons += (m['lecciones'] as List? ?? []).length;
    }
    final bool isCourseCompleted = _completedLessonIds.length >= totalLessons && totalLessons > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          // Botón del Tutor IA (Aura AI 2.0)
          GestureDetector(
            onTap: _openTutorChat,
            child: Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1.5),
              ),
              child: const Center(
                child: Icon(
                  Icons.psychology_rounded,
                  color: Color(0xFF6366F1),
                  size: 26,
                ),
              ),
            ),
          ),
          // Botón Principal (Graduarse o Completar)
          Expanded(
            child: isCourseCompleted
                ? AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: child,
                      );
                    },
                    child: GestureDetector(
                      onTap: _triggerGraduation,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) => Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFF6366F1)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withOpacity(0.3 + (_pulseAnimation.value - 1.0) * 5),
                                blurRadius: 16 + (_pulseAnimation.value - 1.0) * 120,
                                spreadRadius: (_pulseAnimation.value - 1.0) * 30,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.school_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 10),
                              Text(
                                "¡Graduarse!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCompleted ? Colors.green : const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _toggleCompletion,
                    child: Text(
                      _isCompleted ? "Completada" : "Marcar como completada",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    if (!_isEnrolled && !_isInstructor) {
      return Scaffold(
        appBar: AppBar(title: const Text("Acceso denegado")),
        body: const Center(child: Text("Debes inscribirte para ver este curso.")),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text(_currentLesson?['titulo'] ?? "Lección", style: const TextStyle(fontSize: 16)),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  _buildVideoPlayer(),
                  _buildCustomVideoControls(), // Barra de controles personalizados (Velocidad, PiP, Crear Nota)
                  const TabBar(
                    tabs: [
                      Tab(text: "Contenido"),
                      Tab(text: "Recursos"),
                      Tab(text: "Notas / Marcadores"),
                    ],
                    labelColor: Color(0xFF6366F1),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFF6366F1),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: TabBarView(
                            children: [
                              _buildCurriculumList(),
                              _buildResourcesList(),
                              _buildNotesTab(), // Nueva pestaña para visualizar y saltar a notas
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildBottomControl(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Confetti overlay covering the FULL screen
          Align(
            alignment: Alignment.bottomCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.06,
              numberOfParticles: 30,
              maxBlastForce: 60,
              minBlastForce: 25,
              gravity: 0.2,
              colors: const [
                Color(0xFF8B5CF6),
                Color(0xFFA855F7),
                Color(0xFF6366F1),
                Color(0xFFEC4899),
                Color(0xFFF59E0B),
                Color(0xFF10B981),
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
