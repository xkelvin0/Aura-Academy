import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:aura_academy/screens/certificates/graduation_celebration_screen.dart';

class LessonPlayerScreen extends StatefulWidget {
  final String courseId;
  final String initialLessonId;

  const LessonPlayerScreen({super.key, required this.courseId, required this.initialLessonId});

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadAllData(widget.initialLessonId);
  }

  @override
  void dispose() {
    _ytController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _audioPlayer.dispose();
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
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isCourseCompleted
              ? const Color(0xFF8B5CF6) // Púrpura para Graduarse
              : (_isCompleted ? Colors.green : const Color(0xFF6366F1)),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          if (isCourseCompleted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GraduationCelebrationScreen(
                  courseId: widget.courseId,
                  courseTitle: _course?['titulo'] ?? "Curso",
                ),
              ),
            );
          } else {
            _toggleCompletion();
          }
        },
        child: Text(
          isCourseCompleted
              ? "Graduarse"
              : (_isCompleted ? "Completada" : "Marcar como completada"),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
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
      length: 2,
      child: Scaffold(
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
              const TabBar(
                tabs: [Tab(text: "Contenido"), Tab(text: "Recursos")],
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
    );
  }
}
