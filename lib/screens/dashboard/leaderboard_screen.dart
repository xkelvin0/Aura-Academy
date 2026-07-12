import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  // Variables estáticas para pasar logros pendientes desde el reproductor
  static String? pendingMedalName;
  static String? pendingMedalDesc;
  static String? pendingMedalIcon;

  static bool? pendingLevelUp;
  static int? pendingNewLevel;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;

  // Datos del Usuario
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _myMedals = [];
  List<Map<String, dynamic>> _activeQuests = [];

  // Clasificaciones
  List<Map<String, dynamic>> _globalLeaderboard = [];
  List<Map<String, dynamic>> _courseLeaderboard = [];
  List<Map<String, dynamic>> _myCourses = [];
  String? _selectedCourseId;

  // Temporizador para Misiones Diarias (Tiempo restante hasta medianoche)
  Timer? _timer;
  String _timeRemaining = "Calculating...";

  late ConfettiController _confettiController;

  // Medallas del sistema para referencia
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

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
    _startTimer();

    // Validar si venimos redirigidos por un logro desbloqueado o subida de nivel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (LeaderboardScreen.pendingMedalName != null) {
        _showAchievementUnlockedDialog(
          LeaderboardScreen.pendingMedalName!,
          LeaderboardScreen.pendingMedalDesc ?? "",
          LeaderboardScreen.pendingMedalIcon ?? "play_circle_fill",
        );
        LeaderboardScreen.pendingMedalName = null;
        LeaderboardScreen.pendingMedalDesc = null;
        LeaderboardScreen.pendingMedalIcon = null;
      }
      
      if (LeaderboardScreen.pendingLevelUp == true) {
        _showLevelUpDialog(LeaderboardScreen.pendingNewLevel ?? 1);
        LeaderboardScreen.pendingLevelUp = false;
        LeaderboardScreen.pendingNewLevel = null;
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day + 1);
      final difference = midnight.difference(now);

      final hours = difference.inHours.toString().padLeft(2, '0');
      final minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');

      if (mounted) {
        setState(() {
          _timeRemaining = "$hours:$minutes:$seconds";
        });
      }
    });
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Cargar Perfil
      final profileRes = await supabase
          .from('perfiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();
      _profileData = profileRes;

      // 2. Cargar Medallas del Usuario
      final medalsRes = await supabase
          .from('perfiles_medallas')
          .select('*, medallas(*)')
          .eq('perfil_id', user.id);
      _myMedals = List<Map<String, dynamic>>.from(medalsRes);

      // 3. Cargar Misiones del sistema
      final questsRes = await supabase.from('misiones').select('*');
      _activeQuests = List<Map<String, dynamic>>.from(questsRes);
      
      // Fallback local en caso de que la tabla de misiones en la DB venga vacía
      if (_activeQuests.isEmpty) {
        _activeQuests = [
          {
            'titulo': 'Rápido Avance',
            'descripcion': 'Estudia por lo menos 15 minutos (0.25h) el día de hoy.',
            'xp_recompensa': 100,
            'horas_objetivo': 0.25,
            'tipo': 'DIARIA'
          },
          {
            'titulo': 'Estudiante Ejemplar',
            'descripcion': 'Dedica 1 hora de estudio completo hoy.',
            'xp_recompensa': 300,
            'horas_objetivo': 1.00,
            'tipo': 'DIARIA'
          },
          {
            'titulo': 'Maratón de Estudio',
            'descripcion': 'Acumula 5 horas de estudio durante esta semana.',
            'xp_recompensa': 1000,
            'horas_objetivo': 5.00,
            'tipo': 'SEMANAL'
          }
        ];
      }

      // 4. Cargar Cursos inscritos para el selector del Ranking por Curso
      final coursesRes = await supabase
          .from('inscripciones')
          .select('*, cursos(*)')
          .eq('perfil_id', user.id);
      
      _myCourses = List<Map<String, dynamic>>.from(coursesRes);
      if (_myCourses.isNotEmpty) {
        _selectedCourseId = _myCourses.first['curso_id'].toString();
      }

      // 5. Cargar Rankings
      await _loadGlobalLeaderboard();
      await _loadCourseLeaderboard();

      // 6. Calcular horas reales estudiadas HOY dinámicamente
      double todayHours = 0.0;
      try {
        final hoyStr = DateTime.now().toIso8601String().split('T')[0];
        final completedTodayRes = await supabase
            .from('lecciones_completadas')
            .select('*, cursos(duracion_texto)')
            .eq('perfil_id', user.id)
            .gte('fecha_completado', '${hoyStr}T00:00:00')
            .lte('fecha_completado', '${hoyStr}T23:59:59');
        
        final listToday = completedTodayRes as List;
        for (var item in listToday) {
          final String courseId = item['curso_id'].toString();
          final String duracionTexto = item['cursos']?['duracion_texto']?.toString() ?? '10.0';
          final double cursoHoras = double.tryParse(regexpReplace(duracionTexto, '[^0-9\\.]')) ?? 10.0;
          
          final countRes = await supabase
              .from('lecciones')
              .select('id')
              .eq('curso_id', courseId);
          final int totalLecciones = (countRes as List).length;
          if (totalLecciones == 0) continue;
          
          final double leccionHoras = (cursoHoras / totalLecciones).clamp(0.1, 10.0);
          todayHours += leccionHoras;
        }
      } catch (err) {
        debugPrint("Error calculando horas de hoy: $err");
      }

      _todayStudyHours = todayHours;

      // 7. Verificar y otorgar XP de misiones completadas (que aún no se hayan reclamado)
      try {
        final int xpAntes = _profileData?['xp_total'] ?? 0;
        int nivelAntes = 1;
        while (100 * nivelAntes * (nivelAntes + 1) <= xpAntes) nivelAntes++;

        final double horasEstudio = double.tryParse(_profileData?['horas_estudio_total']?.toString() ?? '0.0') ?? 0.0;

        for (var quest in _activeQuests) {
          final String tipo = quest['tipo'] ?? 'DIARIA';
          final double objetivo = double.tryParse(quest['horas_objective']?.toString() ?? quest['horas_objetivo']?.toString() ?? '1.0') ?? 1.0;
          final double progreso = tipo == 'DIARIA' ? _todayStudyHours : horasEstudio;
          if (progreso < objetivo) continue;

          final String questId = quest['id']?.toString() ?? quest['titulo'];
          final String claimKey = tipo == 'DIARIA'
              ? 'mision_${questId}_${DateTime.now().toIso8601String().split('T')[0]}'
              : 'mision_${questId}_semana';

          // Buscar si ya fue reclamada hoy
          final alreadyClaimed = await supabase
              .from('misiones_reclamadas')
              .select('id')
              .eq('perfil_id', user.id)
              .eq('clave', claimKey)
              .maybeSingle();

          if (alreadyClaimed != null) continue;

          // Reclamar: insertar en misiones_reclamadas (El TRIGGER trg_mision_xp sumará el XP automáticamente)
          final int xpGanado = quest['xp_recompensa'] ?? 100;
          await supabase.from('misiones_reclamadas').insert({
            'perfil_id': user.id,
            'clave': claimKey,
            'xp_ganado': xpGanado,
            'fecha': DateTime.now().toIso8601String(),
          });
        }

        // Recargar perfil con XP actualizado
        final profileActualizado = await supabase.from('perfiles').select('*').eq('id', user.id).maybeSingle();
        _profileData = profileActualizado;

        final int xpDespues = _profileData?['xp_total'] ?? 0;
        int nivelDespues = 1;
        while (100 * nivelDespues * (nivelDespues + 1) <= xpDespues) nivelDespues++;

        if (nivelDespues > nivelAntes) {
          if (mounted) {
            _showLevelUpDialog(nivelDespues);
          }
          LeaderboardScreen.pendingLevelUp = false;
        }
      } catch (questErr) {
        debugPrint("Error reclamando XP de misiones: $questErr");
      }

    } catch (e) {
      debugPrint("Error cargando Dashboard de Gamificación: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper local para limpiar texto de duración
  String regexpReplace(String source, String pattern) {
    return source.replaceAll(RegExp(pattern), '');
  }

  double _todayStudyHours = 0.0;

  // Carga clasificación global
  Future<void> _loadGlobalLeaderboard() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final vLunes = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final String semanaInicioStr = "${vLunes.year}-${vLunes.month.toString().padLeft(2, '0')}-${vLunes.day.toString().padLeft(2, '0')}";

    try {
      final res = await supabase
          .from('metas_semanales')
          .select('*, perfiles(*)')
          .eq('semana_inicio', semanaInicioStr)
          .order('horas_estudiadas', ascending: false)
          .limit(15);

      List<Map<String, dynamic>> dbList = List<Map<String, dynamic>>.from(res);
      
      // Creamos una lista de competidores simulados para que la presentación se vea siempre con competidores reales
      List<Map<String, dynamic>> mockPlayers = [
        {
          'horas_estudiadas': 4.8,
          'semana_inicio': semanaInicioStr,
          'perfiles': {'nombre_completo': 'Sofía Alva', 'avatar_url': '', 'id': 'mock1'}
        },
        {
          'horas_estudiadas': 3.5,
          'semana_inicio': semanaInicioStr,
          'perfiles': {'nombre_completo': 'Alejandro Ruiz', 'avatar_url': '', 'id': 'mock2'}
        },
        {
          'horas_estudiadas': 2.1,
          'semana_inicio': semanaInicioStr,
          'perfiles': {'nombre_completo': 'Emily Watson', 'avatar_url': '', 'id': 'mock3'}
        },
        {
          'horas_estudiadas': 1.6,
          'semana_inicio': semanaInicioStr,
          'perfiles': {'nombre_completo': 'Juan Pérez', 'avatar_url': '', 'id': 'mock4'}
        },
        {
          'horas_estudiadas': 0.8,
          'semana_inicio': semanaInicioStr,
          'perfiles': {'nombre_completo': 'Clara Méndez', 'avatar_url': '', 'id': 'mock5'}
        }
      ];

      // Buscar si el usuario actual ya tiene registro en la base de datos
      final userDbRecord = dbList.firstWhere(
        (item) => item['perfiles']?['id'] == user.id,
        orElse: () => {},
      );

      // Horas del usuario actual
      double userHours = 0.0;
      if (userDbRecord.isNotEmpty) {
        userHours = double.tryParse(userDbRecord['horas_estudiadas']?.toString() ?? '0.0') ?? 0.0;
      } else if (_profileData != null) {
        userHours = double.tryParse(_profileData?['horas_estudio_hoy']?.toString() ?? '0.0') ?? 0.0;
      }

      // Creamos la lista final combinada
      List<Map<String, dynamic>> combinedList = [];

      // 1. Agregar a los usuarios que ya están en base de datos real (excluyendo duplicados del usuario)
      for (var item in dbList) {
        if (item['perfiles']?['id'] != user.id) {
          combinedList.add(item);
        }
      }

      // 2. Insertar al usuario actual con sus horas dinámicas reales
      if (_profileData != null) {
        combinedList.add({
          'horas_estudiadas': userHours,
          'semana_inicio': semanaInicioStr,
          'perfiles': _profileData
        });
      }

      // 3. Rellenar con los competidores simulados
      for (var mock in mockPlayers) {
        if (!combinedList.any((item) => item['perfiles']?['nombre_completo'] == mock['perfiles']?['nombre_completo'])) {
          combinedList.add(mock);
        }
      }

      // 4. Ordenar descendentemente por horas estudiadas
      combinedList.sort((a, b) {
        double hoursA = double.tryParse(a['horas_estudiadas']?.toString() ?? '0.0') ?? 0.0;
        double hoursB = double.tryParse(b['horas_estudiadas']?.toString() ?? '0.0') ?? 0.0;
        return hoursB.compareTo(hoursA);
      });

      _globalLeaderboard = combinedList;
    } catch (e) {
      debugPrint("Error cargando ranking global: $e");
    }
  }

  // Carga clasificación por curso específico
  Future<void> _loadCourseLeaderboard() async {
    if (_selectedCourseId == null) return;

    try {
      // Obtenemos los alumnos inscritos en el curso específico y su progreso general
      final res = await supabase
          .from('inscripciones')
          .select('*, perfiles(*)')
          .eq('curso_id', _selectedCourseId!)
          .order('progreso_porcentaje', ascending: false)
          .limit(15);

      List<Map<String, dynamic>> dbList = List<Map<String, dynamic>>.from(res);

      // Competidores ficticios del curso para dar sensación de comunidad en el Pitch
      List<Map<String, dynamic>> mockCoursePlayers = [
        {
          'progreso_porcentaje': 80,
          'perfiles': {'nombre_completo': 'Sofía Alva', 'avatar_url': '', 'id': 'mock1'}
        },
        {
          'progreso_porcentaje': 60,
          'perfiles': {'nombre_completo': 'Alejandro Ruiz', 'avatar_url': '', 'id': 'mock2'}
        },
        {
          'progreso_porcentaje': 35,
          'perfiles': {'nombre_completo': 'Emily Watson', 'avatar_url': '', 'id': 'mock3'}
        },
        {
          'progreso_porcentaje': 10,
          'perfiles': {'nombre_completo': 'Juan Pérez', 'avatar_url': '', 'id': 'mock4'}
        }
      ];

      // Buscar si el usuario actual ya está inscrito en la DB
      final userRecord = dbList.firstWhere(
        (item) => item['perfiles']?['id'] == _profileData?['id'],
        orElse: () => {},
      );

      int userProgress = 0;
      if (userRecord.isNotEmpty) {
        userProgress = userRecord['progreso_porcentaje'] ?? 0;
      }

      List<Map<String, dynamic>> combinedList = [];

      // 1. Agregar alumnos reales de la DB
      for (var item in dbList) {
        if (item['perfiles']?['id'] != _profileData?['id']) {
          combinedList.add(item);
        }
      }

      // 2. Agregar al propio usuario actual
      if (_profileData != null) {
        combinedList.add({
          'progreso_porcentaje': userProgress,
          'perfiles': _profileData
        });
      }

      // 3. Mezclar competidores ficticios
      for (var mock in mockCoursePlayers) {
        if (!combinedList.any((item) => item['perfiles']?['nombre_completo'] == mock['perfiles']?['nombre_completo'])) {
          combinedList.add(mock);
        }
      }

      // 4. Ordenar descendentemente por progreso
      combinedList.sort((a, b) {
        int pctA = a['progreso_porcentaje'] ?? 0;
        int pctB = b['progreso_porcentaje'] ?? 0;
        return pctB.compareTo(pctA);
      });

      _courseLeaderboard = combinedList;
    } catch (e) {
      debugPrint("Error cargando ranking de curso: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              'Aura Centro de Logros',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1E293B)),
            ),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E293B),
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF6366F1),
              labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11),
              tabs: const [
                Tab(text: "Misiones"),
                Tab(text: "Global"),
                Tab(text: "Por Curso"),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuestsView(),
                    _buildGlobalRankingView(),
                    _buildCourseRankingView(),
                  ],
                ),
        ),
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
    );
  }

  // VISTA 1: Estatus del Estudiante y Misiones Activas
  Widget _buildQuestsView() {
    final int xp = _profileData?['xp_total'] ?? 0;
    // Sistema XP progresivo: nivel N requiere N*200 XP (100*N*(N-1) acumulado)
    int nivel = 1;
    while (100 * nivel * (nivel + 1) <= xp) nivel++;
    final double horasEstudio = double.tryParse(_profileData?['horas_estudio_total']?.toString() ?? '0.0') ?? 0.0;
    final int racha = _profileData?['racha_dias'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Tarjeta de Estatus Premium
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white24,
                    child: Text(
                      _profileData?['nombre_completo']?.substring(0, 1).toUpperCase() ?? "U",
                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profileData?['nombre_completo'] ?? "Usuario Aura",
                          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          "NIVEL $nivel • Rango Estudiante Aura",
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                    child: Text("$xp XP", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final int xpParaNivelActual = 100 * (nivel - 1) * nivel;
                  final int xpParaSiguienteNivel = 100 * nivel * (nivel + 1);
                  final double progresoNivel = ((xp - xpParaNivelActual) / (xpParaSiguienteNivel - xpParaNivelActual)).clamp(0.0, 1.0);
                  
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        value: progresoNivel,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        color: const Color(0xFF2DD4BF),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("$xp / $xpParaSiguienteNivel XP", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10)),
                          Text("Nivel ${nivel + 1} en ${xpParaSiguienteNivel - xp} XP", style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  );
                }
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat("🔥 $racha días", "Racha Activa"),
                  _buildMiniStat("⏱️ ${horasEstudio.toStringAsFixed(1)}h", "Horas Totales"),
                  _buildMiniStat("🏆 ${_myMedals.length} Medallas", "Desbloqueadas"),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Sección Misiones
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Aura Quests (Misiones)", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.red, size: 14),
                const SizedBox(width: 4),
                Text(
                  "Reinicia en: $_timeRemaining",
                  style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...List.generate(_activeQuests.length, (index) {
          final quest = _activeQuests[index];
          final String tipo = quest['tipo'] ?? 'DIARIA';
          final double objetivo = double.tryParse(quest['horas_objective']?.toString() ?? quest['horas_objetivo']?.toString() ?? '1.0') ?? 1.0;
           final double progreso = tipo == 'DIARIA' ? _todayStudyHours : horasEstudio;
           final double pct = (progreso / objetivo).clamp(0.0, 1.0);
           final bool isFinished = pct >= 1.0;

          return FadeSlideTransition(
            delay: Duration(milliseconds: 100 * (index + 2)), // Retraso escalonado
            child: Card(
              elevation: 0,
              color: isFinished ? const Color(0xFFE6FFFA) : const Color(0xFFF8FAFC),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), 
                side: BorderSide(color: isFinished ? const Color(0xFF99F6E4) : Colors.grey.shade200)
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isFinished ? const Color(0xFFCCFBF1) : const Color(0xFFEEF2F6),
                      child: Icon(
                        isFinished ? Icons.stars_rounded : (tipo == 'DIARIA' ? Icons.calendar_today_rounded : Icons.military_tech_rounded), 
                        color: isFinished ? const Color(0xFF0D9488) : const Color(0xFF6366F1), 
                        size: 20
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(quest['titulo'], overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: isFinished ? const Color(0xFF0F766E) : const Color(0xFF1E293B))),
                              ),
                              if (isFinished) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                              ]
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(quest['descripcion'], maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: isFinished ? const Color(0xFF0F766E).withOpacity(0.7) : Colors.grey, fontSize: 11)),
                          const SizedBox(height: 10),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: pct),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutBack,
                            builder: (context, animValue, child) {
                              return LinearProgressIndicator(
                                value: animValue,
                                backgroundColor: isFinished ? const Color(0xFFCCFBF1) : Colors.grey.shade200,
                                color: const Color(0xFF2DD4BF),
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(2.5),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 64,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isFinished ? "¡Listo!" : "+${quest['xp_recompensa']} XP", 
                            style: GoogleFonts.montserrat(
                              color: isFinished ? const Color(0xFF0D9488) : const Color(0xFF2DD4BF), 
                              fontWeight: FontWeight.bold, 
                              fontSize: 10.5
                            )
                          ),
                          const SizedBox(height: 4),
                          Text("${(pct * 100).toInt()}%", style: GoogleFonts.outfit(color: isFinished ? const Color(0xFF0D9488) : Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),

        // Sección de Logros / Medallas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Mis Logros & Medallas", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(
              "${_myMedals.length} de ${medallasDelSistema.length} obtenidas",
              style: GoogleFonts.outfit(color: const Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 12),
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
            final ganadasTipos = _myMedals.map((m) => m['medallas']?['requisito_tipo']?.toString()).toSet();
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
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMiniStat(String topText, String bottomText) {
    return Column(
      children: [
        Text(topText, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Text(bottomText, style: GoogleFonts.outfit(color: Colors.white60, fontSize: 9)),
      ],
    );
  }

  // VISTA 2: Ranking Global (Acumulado general)
  Widget _buildGlobalRankingView() {
    if (_globalLeaderboard.isEmpty) {
      return Center(
        child: Text(
          "No hay clasificaciones registradas esta semana.",
          style: GoogleFonts.outfit(color: Colors.grey),
        ),
      );
    }

    // Identificar los 3 primeros puestos para el podio
    Map<String, dynamic>? firstPlace = _globalLeaderboard.isNotEmpty ? _globalLeaderboard[0] : null;
    Map<String, dynamic>? secondPlace = _globalLeaderboard.length > 1 ? _globalLeaderboard[1] : null;
    Map<String, dynamic>? thirdPlace = _globalLeaderboard.length > 2 ? _globalLeaderboard[2] : null;

    // Elementos del 4 en adelante para la lista
    List<Map<String, dynamic>> restOfList = _globalLeaderboard.length > 3 ? _globalLeaderboard.sublist(3) : [];

    return Column(
      children: [
        // Mensaje Motivacional Basado en tu posición
        _buildMotivationalBanner(),
        
        // Podio Visual
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2do Lugar (Plata)
              if (secondPlace != null)
                _buildPodiumPillar(
                  perfil: secondPlace['perfiles'],
                  horas: double.tryParse(secondPlace['horas_estudiadas']?.toString() ?? '0.0') ?? 0.0,
                  puesto: 2,
                  altura: 75.0,
                  colorPilar: const Color(0xFFE2E8F0),
                  colorTexto: const Color(0xFF64748B),
                ),
              
              // 1er Lugar (Oro)
              if (firstPlace != null)
                _buildPodiumPillar(
                  perfil: firstPlace['perfiles'],
                  horas: double.tryParse(firstPlace['horas_estudiadas']?.toString() ?? '0.0') ?? 0.0,
                  puesto: 1,
                  altura: 105.0,
                  colorPilar: const Color(0xFFFEF3C7),
                  colorTexto: const Color(0xFFD97706),
                ),
              
              // 3er Lugar (Bronce)
              if (thirdPlace != null)
                _buildPodiumPillar(
                  perfil: thirdPlace['perfiles'],
                  horas: double.tryParse(thirdPlace['horas_estudiadas']?.toString() ?? '0.0') ?? 0.0,
                  puesto: 3,
                  altura: 55.0,
                  colorPilar: const Color(0xFFFFEDD5),
                  colorTexto: const Color(0xFFC2410C),
                ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFF1F5F9)),

        // Lista de puestos del 4 en adelante
        Expanded(
          child: restOfList.isEmpty
              ? Center(
                  child: Text(
                    "¡Completa lecciones para subir de puesto!",
                    style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: restOfList.length,
                  itemBuilder: (context, idx) {
                    final item = restOfList[idx];
                    final perfil = item['perfiles'];
                    final double horas = double.tryParse(item['horas_estudiadas']?.toString() ?? '0.0') ?? 0.0;
                    final String nombre = perfil?['nombre_completo'] ?? "Usuario Aura";
                    final String avatar = perfil?['avatar_url'] ?? "";
                    final int puestoReal = idx + 4;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Center(
                              child: Text(
                                "$puestoReal",
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFE2E8F0),
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty 
                                ? Text(nombre.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)) 
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              nombre,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            "${horas.toStringAsFixed(1)}h",
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6366F1),
                              fontSize: 12,
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
  }

  // Banner motivacional basado en la clasificación actual
  Widget _buildMotivationalBanner() {
    final user = supabase.auth.currentUser;
    int miPuesto = -1;
    if (user != null) {
      miPuesto = _globalLeaderboard.indexWhere((item) => item['perfiles']?['id'] == user.id);
    }

    String emoji = "🚀";
    String titulo = "¡Sigue sumando!";
    String desc = "Completa lecciones para entrar en el podio esta semana.";

    if (miPuesto == 0) {
      emoji = "👑";
      titulo = "¡Estás liderando!";
      desc = "Vas en el puesto #1 esta semana. ¡Sigue brillando!";
    } else if (miPuesto > 0 && miPuesto <= 2) {
      emoji = "🔥";
      titulo = "¡En el podio!";
      desc = "¡Fantástico! Estás en el Top 3. A un paso de la victoria.";
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pilar de podio individual
  Widget _buildPodiumPillar({
    required Map<String, dynamic>? perfil,
    required double horas,
    required int puesto,
    required double altura,
    required Color colorPilar,
    required Color colorTexto,
  }) {
    final String nombre = perfil?['nombre_completo'] ?? "Estudiante";
    final String avatar = perfil?['avatar_url'] ?? "";
    final String inicial = nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : "U";

    IconData iconData = Icons.emoji_events_rounded;
    if (puesto == 1) iconData = Icons.emoji_events_rounded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Corona en Puesto 1
        if (puesto == 1)
          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 24)
        else
          const SizedBox(height: 24),
        
        const SizedBox(height: 4),

        // Avatar
        CircleAvatar(
          radius: puesto == 1 ? 26 : 22,
          backgroundColor: colorPilar,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? Text(
                  inicial,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                    fontSize: puesto == 1 ? 16 : 14,
                  ),
                )
              : null,
        ),
        
        const SizedBox(height: 8),

        // Nombre
        SizedBox(
          width: 85,
          child: Text(
            nombre,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: puesto == 1 ? 12.5 : 11.5,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),

        // Horas
        Text(
          "${horas.toStringAsFixed(1)}h",
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6366F1),
          ),
        ),

        const SizedBox(height: 8),

        // Pilar Físico
        Container(
          width: 65,
          height: altura,
          decoration: BoxDecoration(
            color: colorPilar,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconData, color: colorTexto, size: puesto == 1 ? 18 : 15),
                const SizedBox(width: 2),
                Text(
                  "#$puesto",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                    fontSize: puesto == 1 ? 13 : 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // VISTA 3: Ranking Específico de Curso (Progreso en porcentaje de finalización)
  Widget _buildCourseRankingView() {
    if (_myCourses.isEmpty) {
      return Center(
        child: Text("Debes inscribirte en al menos un curso para competir.", style: GoogleFonts.outfit(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        // Selector de Cursos
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCourseId,
                isExpanded: true,
                items: _myCourses.map((enroll) {
                  final curso = enroll['cursos'];
                  return DropdownMenuItem<String>(
                    value: curso['id'].toString(),
                    child: Text(curso['titulo'] ?? "Curso", style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCourseId = val;
                      _isLoading = true;
                    });
                    _loadCourseLeaderboard().then((_) {
                      if (mounted) setState(() => _isLoading = false);
                    });
                  }
                },
              ),
            ),
          ),
        ),

        // Lista de Ranking por Curso
        Expanded(
          child: _courseLeaderboard.isEmpty
              ? Center(child: Text("Nadie ha avanzado en este curso aún.", style: GoogleFonts.outfit(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _courseLeaderboard.length,
                  itemBuilder: (context, idx) {
                    final item = _courseLeaderboard[idx];
                    final perfil = item['perfiles'];
                    final int pct = item['progreso_porcentaje'] ?? 0;
                    final String nombre = perfil?['nombre_completo'] ?? "Usuario Aura";
                    final String avatar = perfil?['avatar_url'] ?? "";

                    Color itemColor = const Color(0xFFF8FAFC);
                    Widget leadWidget = Text("${idx + 1}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF64748B)));

                    if (idx == 0) {
                      itemColor = const Color(0xFFFEF3C7);
                      leadWidget = const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 22);
                    } else if (idx == 1) {
                      itemColor = const Color(0xFFF1F5F9);
                      leadWidget = const Icon(Icons.emoji_events_rounded, color: Color(0xFF64748B), size: 22);
                    } else if (idx == 2) {
                      itemColor = const Color(0xFFFFEDD5);
                      leadWidget = const Icon(Icons.emoji_events_rounded, color: Color(0xFFC2410C), size: 22);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          SizedBox(width: 24, child: Center(child: leadWidget)),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFE2E8F0),
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty ? Text(nombre.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(nombre, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), fontSize: 14)),
                          ),
                          Text("$pct%", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF2DD4BF), fontSize: 13)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Diálogo Premium para celebrar la medalla desbloqueada
  void _showAchievementUnlockedDialog(String nombre, String desc, String icono) {
    IconData iconData;
    switch (icono) {
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
                ),
                child: Icon(iconData, color: const Color(0xFF6366F1), size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                "¡Logro Desbloqueado!",
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF6366F1),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nombre,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  "¡Espléndido!",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Pantalla completa de celebración al subir de nivel (estilo graduación)
  void _showLevelUpDialog(int newLevel) {
    _confettiController.play();
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _LevelUpCelebrationOverlay(
            newLevel: newLevel,
            profileData: _profileData,
            onDismiss: () {
              _confettiController.stop();
              Navigator.pop(context);
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

// ─── Overlay de Celebración de Nivel ────────────────────────────────────────
class _LevelUpCelebrationOverlay extends StatefulWidget {
  final int newLevel;
  final Map<String, dynamic>? profileData;
  final VoidCallback onDismiss;

  const _LevelUpCelebrationOverlay({
    required this.newLevel,
    required this.profileData,
    required this.onDismiss,
  });

  @override
  State<_LevelUpCelebrationOverlay> createState() => _LevelUpCelebrationOverlayState();
}

class _LevelUpCelebrationOverlayState extends State<_LevelUpCelebrationOverlay> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  final List<_ConfettiDot> _dots = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _scaleAnimation = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);
    final rng = Random();
    for (int i = 0; i < 80; i++) {
      _dots.add(_ConfettiDot(
        x: rng.nextDouble(),
        y: rng.nextDouble() * -1,
        color: [
          const Color(0xFF8B5CF6), const Color(0xFF6366F1), const Color(0xFFEC4899),
          const Color(0xFFF59E0B), const Color(0xFF10B981), Colors.white,
        ][rng.nextInt(6)],
        size: rng.nextDouble() * 10 + 5,
        speed: rng.nextDouble() * 0.008 + 0.004,
      ));
    }
    _playSound();
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/level_up.mp3'));
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String nombre = widget.profileData?['nombre_completo']?.toString().split(' ')[0].toUpperCase() ?? "ESTUDIANTE";
    final String? avatar = widget.profileData?['avatar_url'];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fondo degradado premium
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFA855F7)],
              ),
            ),
          ),

          // Confeti animado
          ..._dots.map((d) => _AnimatedDot(dot: d)),

          // Contenido central
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.97),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar con insignia de nivel
                    Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                          ),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: const Color(0xFFEEF2FF),
                            backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar == null || avatar.isEmpty
                                ? Text(
                                    nombre.substring(0, 1),
                                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                  )
                                : null,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -22),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "⬆ LVL ${widget.newLevel}",
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "¡SUBISTE DE NIVEL!",
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nombre,
                      style: GoogleFonts.montserrat(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Insignia de nivel grande
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Text(
                        "${widget.newLevel}",
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Has alcanzado el Nivel ${widget.newLevel}.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Sigue estudiando para dominar el podio.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: widget.onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor: const Color(0xFF6366F1).withOpacity(0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.rocket_launch_rounded),
                          const SizedBox(width: 10),
                          Text(
                            "¡INCREÍBLE!",
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiDot {
  final double x;
  double y;
  final Color color;
  final double size;
  final double speed;
  _ConfettiDot({required this.x, required this.y, required this.color, required this.size, required this.speed});
}

class _AnimatedDot extends StatefulWidget {
  final _ConfettiDot dot;
  const _AnimatedDot({required this.dot});
  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late double _y;

  @override
  void initState() {
    super.initState();
    _y = widget.dot.y;
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _ctrl.addListener(() {
      if (mounted) setState(() {
        _y += widget.dot.speed;
        if (_y > 1) _y = -0.1;
      });
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bool isCircle = Random().nextBool();
    return Align(
      alignment: Alignment(widget.dot.x * 2 - 1, _y * 2 - 1),
      child: Container(
        width: widget.dot.size,
        height: widget.dot.size,
        decoration: BoxDecoration(
          color: widget.dot.color.withOpacity(0.85),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : (Random().nextBool() ? BorderRadius.circular(2) : null),
        ),
      ),
    );
  }
}

// Widget auxiliar para animar la entrada escalonada (Fade + Slide)
class FadeSlideTransition extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const FadeSlideTransition({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<FadeSlideTransition> createState() => _FadeSlideTransitionState();
}

class _FadeSlideTransitionState extends State<FadeSlideTransition> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.fastOutSlowIn)),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: FractionalTranslation(
            translation: _slideAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
