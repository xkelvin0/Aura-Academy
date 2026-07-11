import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:async'; // <--- Falta esta importación
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- Importación necesaria
import 'package:aura_academy/screens/auth/welcome_screen.dart';
import 'package:aura_academy/screens/profile/profile_screen.dart';
import 'package:aura_academy/screens/courses/category_selection_screen.dart';
import 'package:aura_academy/screens/courses/course_detail_screen.dart';
import 'package:aura_academy/screens/courses/search_screen.dart';
import 'package:aura_academy/screens/courses/my_courses_screen.dart';
import 'package:aura_academy/screens/profile/edit_profile_screen.dart';
import 'package:aura_academy/screens/profile/settings_screen.dart';
import 'package:aura_academy/screens/instructor/course_structure_screen.dart';
import 'package:aura_academy/screens/courses/lesson_player_screen.dart';
import 'package:aura_academy/screens/dashboard/wishlist_screen.dart';
import 'package:aura_academy/screens/instructor/instructor_panel_screen.dart'; // <--- Importación nueva
import 'package:aura_academy/widgets/aura_chat_widget.dart';

class DashboardScreen extends StatefulWidget {
  // Canal global para notificar cambios en los cursos (likes, vistas, etc)
  static final courseUpdateController = StreamController<void>.broadcast();
  static final searchStreamController = StreamController<String>.broadcast();

  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;
  int _selectedIndex = 0;
  String _userName = "Estudiante";
  bool _isLoading = true;
  Stream<List<Map<String, dynamic>>>? _profileStream; // <--- Stream en tiempo real

  // Variables Dinámicas Reales
  List<Map<String, dynamic>> _enrollments = [];
  List<Map<String, dynamic>> _featuredCourses = [];
  List<Map<String, dynamic>> _wishlistCourses = []; // <--- Nueva lista
  double _weeklyHours = 0.0;
  int _weeklyPercent = 0;
  double _userMetaHours = 10.0; // <--- Meta dinámica
  List<Map<String, dynamic>> _userCategories = [];
  final ScrollController _wishlistController = ScrollController(); // <--- Controlador para las flechas
  String? _activeFilterCategoryId; // Filtro actual
  bool _isInstructor = false; // <--- Nuevo: Detectar si es instructor
  List<Map<String, dynamic>> _myCreatedCourses = []; // <--- Cursos creados por el instructor
  bool _isFiltering = false; // Estado de carga del filtro

  @override
  void initState() {
    super.initState();
    _initRealtimeProfile();
    _loadData();

    // Sincronización Global
    DashboardScreen.courseUpdateController.stream.listen((_) {
      if (mounted) _loadData();
    });
  }

  void _initRealtimeProfile() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      _profileStream = supabase
          .from('perfiles')
          .stream(primaryKey: ['id'])
          .eq('id', user.id);
    }
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // 1. Obtener Nombre del Perfil
        final profileResponse = await supabase
            .from('perfiles')
            .select('nombre_completo, meta_horas_semanal, es_instructor') // <--- Agregamos es_instructor
            .eq('id', user.id)
            .maybeSingle();
        
        final double metaUsuario = (profileResponse?['meta_horas_semanal'] ?? 10.0).toDouble();
        
        // 2. Obtener Inscripciones en progreso (El card principal)
        final enrollmentsRes = await supabase
            .from('inscripciones')
            .select('*, cursos(*, categorias(nombre))')
            .eq('perfil_id', user.id)
            .eq('en_progreso', true)
            .order('ultima_vez_visto', ascending: false);
            
        // 3. Obtener Cursos Destacados de la Tienda global (Mejor puntuados y más vistos)
        final featuredRes = await supabase
            .from('cursos')
            .select('*, perfiles(nombre_completo)') 
            .order('rating_promedio', ascending: false)
            .order('vistas', ascending: false)
            .limit(10);
            
        // 4. Obtener Meta Semanal de este usuario
        final metaResList = await supabase
            .from('metas_semanales')
            .select('*')
            .eq('perfil_id', user.id)
            .limit(1);
        final metaRes = metaResList.isNotEmpty ? metaResList.first : null;

        // 5. Obtener Categorías Seleccionadas por el usuario
        final userCatsRes = await supabase
            .from('perfil_categorias')
            .select('categorias(*)')
            .eq('perfil_id', user.id);

        // 6. Obtener Lista de Deseos (NUEVO)
        final wishlistRes = await supabase
            .from('lista_deseos')
            .select('*, cursos(*, perfiles(nombre_completo))')
            .eq('perfil_id', user.id)
            .order('fecha_agregado', ascending: false);

        // 7. Obtener Cursos Creados (Solo si es instructor)
        List<Map<String, dynamic>> createdCourses = [];
        if (profileResponse?['es_instructor'] == true) {
          final res = await supabase
              .from('cursos')
              .select('*, categorias(nombre)')
              .eq('instructor_id', user.id)
              .order('fecha_creacion', ascending: false);
          createdCourses = List<Map<String, dynamic>>.from(res);
        }

        // Mapear categorías del usuario
        if (userCatsRes != null) {
          _userCategories = (userCatsRes as List)
              .map((item) => item['categorias'] as Map<String, dynamic>)
              .toList();
        }

        // VERIFICACIÓN CRÍTICA: Si no hay categorías, mandamos a elegir ANTES de apagar el cargador
        if (_userCategories.isEmpty && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const CategorySelectionScreen()),
            (route) => false,
          );
          return; // Salimos para no ejecutar el setState de abajo
        }

        if (mounted) {
          setState(() {
            _userName = profileResponse?['nombre_completo'] ?? 
                        user.userMetadata?['full_name'] ?? 
                        user.email?.split('@')[0] ??
                        "Usuario";
            _isInstructor = profileResponse?['es_instructor'] == true; // <--- Guardamos el rol
            _myCreatedCourses = createdCourses; // <--- Guardamos sus cursos
            _enrollments = List<Map<String, dynamic>>.from(enrollmentsRes)
                .where((e) => e['cursos']['instructor_id'] != user.id)
                .toList(); // <--- Filtramos para no ver nuestros propios cursos en "Continuar Aprendiendo"
            _featuredCourses = List<Map<String, dynamic>>.from(featuredRes);
            _wishlistCourses = (wishlistRes as List).map((e) => e['cursos'] as Map<String, dynamic>).toList();
            
            if (metaRes != null) {
              _weeklyHours = double.parse(metaRes['horas_estudiadas'].toString());
              _userMetaHours = metaUsuario;
              _weeklyPercent = ((_weeklyHours / _userMetaHours) * 100).toInt();
              if (_weeklyPercent > 100) _weeklyPercent = 100;
            } else {
              _weeklyHours = 0.0;
              _userMetaHours = metaUsuario;
              _weeklyPercent = 0;
            }
            
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error crítico cargando Tablero dinámico: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFilteredCourses(String? categoryId) async {
    setState(() {
      _activeFilterCategoryId = categoryId;
      _isFiltering = true;
    });

    try {
      dynamic query = supabase
          .from('cursos')
          .select('*, perfiles(nombre_completo)');

      if (categoryId != null) {
        query = query.eq('categoria_id', categoryId);
      } else {
        // Por defecto: Mostramos los mejores de toda la plataforma
        query = query.order('rating_promedio', ascending: false)
                     .order('vistas', ascending: false);
      }

      final res = await query.limit(10);
      
      if (mounted) {
        setState(() {
          _featuredCourses = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint("Error filtrando cursos: $e");
    } finally {
      if (mounted) setState(() => _isFiltering = false);
    }
  }

  Future<void> _toggleWishlist(String courseId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Buscar el curso para ver quién es el instructor
    final course = _featuredCourses.firstWhere((c) => c['id'].toString() == courseId.toString(), orElse: () => {});
    
    // BLOQUEO DE AUTO-LIKE
    if (course['instructor_id'] == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("👨‍🏫 No puedes darte auto-like a tu propio curso."),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
      return;
    }

    final isExist = _wishlistCourses.any((c) => c['id'].toString() == courseId.toString());

    try {
      if (isExist) {
        await supabase
            .from('lista_deseos')
            .delete()
            .eq('perfil_id', user.id)
            .eq('curso_id', courseId);
      } else {
        await supabase
            .from('lista_deseos')
            .insert({
              'perfil_id': user.id,
              'curso_id': courseId,
            });
      }
      
      // RECARGAR DATOS LOCALES
      await _loadData();
      
      // NOTIFICAR A LAS DEMÁS PESTAÑAS (SearchScreen, InstructorPanel, etc)
      DashboardScreen.courseUpdateController.add(null);
    } catch (e) {
      debugPrint("Error wishlist: $e");
    }
  }

  Future<void> _showGoalSettings() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    double currentMeta = 10.0;
    try {
      final res = await supabase.from('perfiles').select('meta_horas_semanal').eq('id', user.id).single();
      currentMeta = (res['meta_horas_semanal'] ?? 10.0).toDouble();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        double tempMeta = currentMeta;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Tu Meta Semanal", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("¿Cuántas horas quieres estudiar esta semana?", style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 32),
                  Text("${tempMeta.toStringAsFixed(1)} horas", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                  Slider(
                    value: tempMeta,
                    min: 1,
                    max: 40,
                    divisions: 78,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (val) => setModalState(() => tempMeta = val),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      await supabase.from('perfiles').update({'meta_horas_semanal': tempMeta}).eq('id', user.id);
                      if (mounted) {
                        Navigator.pop(context);
                        _loadData(); // Recargar Dashboard
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Meta actualizada! 🚀")));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Guardar Meta", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ELIMINADO EL BLOQUEO TOTAL DE CARGA
    // Ahora el Scaffold se construye de inmediato

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final profile = snapshot.data!.first;
          _userName = profile['nombre_completo'] ?? _userName;
        }

        final List<Widget> pages = [
          _buildHomeContent(), 
          const SearchScreen(), 
          MyCoursesScreen(onBack: () => setState(() => _selectedIndex = 0)), 
          const ProfileScreen(), 
        ];

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: pages,
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
          drawer: _buildDrawer(),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                useSafeArea: false,
                builder: (ctx) => AnimatedPadding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: SizedBox(
                    height: MediaQuery.of(ctx).size.height * 0.80,
                    child: AuraChatWidget(
                      onAction: (action) {
                        if (action.type == 'navigate_tab') {
                          final idx = int.tryParse(action.param ?? '0') ?? 0;
                          setState(() {
                            _selectedIndex = idx;
                          });
                        } else if (action.type == 'search_courses') {
                          setState(() {
                            _selectedIndex = 1; // Tab de búsqueda/exploración
                          });
                          // Usar un delay para dar tiempo a que cargue la pantalla y luego simular la búsqueda
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (action.param != null) {
                              DashboardScreen.searchStreamController.add(action.param!);
                            }
                          });
                        } else if (action.type == 'open_certificates') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CertificatesScreen()),
                          );
                        } else if (action.type == 'open_settings') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        }
                      },
                    ),
                  ),
                ),
              );
            },
            backgroundColor: const Color(0xFF6366F1),
            elevation: 6,
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
          ),
        );
      }
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _profileStream,
        builder: (context, snapshot) {
          String name = _userName;
          String email = supabase.auth.currentUser?.email ?? "estudiante@aura.edu";
          String? avatarUrl;
          
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final profile = snapshot.data!.first;
            name = profile['nombre_completo'] ?? name;
            avatarUrl = profile['avatar_url'];
          }

          final bool hasAvatar = avatarUrl != null && avatarUrl.toString().trim().isNotEmpty;

          return Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: hasAvatar ? NetworkImage(avatarUrl.toString()) : null,
                  child: !hasAvatar 
                    ? Text(
                        _getInitials(name),
                        style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 24),
                      )
                    : null,
                ),
                accountName: Text(
                  name,
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                accountEmail: Text(
                  email,
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                ),
              ),
              _buildDrawerItem(Icons.home_rounded, "Inicio", () {
                Navigator.pop(context); // Cierra el menú
                setState(() => _selectedIndex = 0); // Va a Inicio
              }),
              _buildDrawerItem(Icons.library_books_rounded, "Mis Cursos", () {
                Navigator.pop(context); // Cierra el menú
                setState(() => _selectedIndex = 2); // Va a Mis Cursos
              }),
              _buildDrawerItem(Icons.help_outline_rounded, "Soporte y Ayuda", () async {
                Navigator.pop(context);
                final Uri whatsappUrl = Uri.parse("https://wa.me/51936726266?text=Hola%20creador%20de%20Aura%20Academy,%20necesito%20ayuda%20con%20mi%20cuenta.");
                if (await canLaunchUrl(whatsappUrl)) {
                  await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                } else {
                  debugPrint("No se pudo abrir WhatsApp");
                }
              }),
              const Divider(indent: 20, endIndent: 20),
              _buildDrawerItem(Icons.settings_outlined, "Configuración", () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              }),
              const Spacer(),
              _buildDrawerItem(Icons.logout_rounded, "Cerrar Sesión", () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text("¿Cerrar Sesión?"),
                    content: const Text("¿Estás seguro de que deseas salir de Aura Academy?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true), 
                        child: const Text("Salir", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    // Cerramos sesión directamente
                    await supabase.auth.signOut();

                    // Forzamos la salida al WelcomeScreen limpiando TODA la pila de navegación
                    // Esto cerrará el drawer automáticamente al destruir el Dashboard
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    debugPrint("Error al cerrar sesión: $e");
                  }
                }
              }, color: Colors.redAccent),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF64748B)),
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 14, 
          fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFF1E293B),
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      color: const Color(0xFF6366F1),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Importante para que el scroll funcione con RefreshIndicator
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSearchBar(),
            const SizedBox(height: 32),
            
            if (_isInstructor) ...[
              _buildInstructorShortcutCard(),
              const SizedBox(height: 32),
              
              if (_myCreatedCourses.isNotEmpty) ...[
                _buildSectionTitle("Gestiona tus cursos"),
                const SizedBox(height: 16),
                _buildInstructorCoursesHorizontal(),
                const SizedBox(height: 32),
              ],
            ],
            
            _buildSectionTitle("Continuar Aprendiendo"),
            const SizedBox(height: 16),
            if (_enrollments.isEmpty)
               _buildEmptyState(
                 icon: Icons.rocket_launch_rounded, 
                 title: "Estás a un clic de empezar", 
                 subtitle: "Explora nuestras categorías y matricúlate en tu primer curso."
               )
            else
               _buildContinueLearningCard(_enrollments.first), 
            
            const SizedBox(height: 32),
            _buildWeeklyGoalCard(),
            const SizedBox(height: 32),

            _buildSectionTitle("Categorías para ti"),
            const SizedBox(height: 16),
            _buildDisciplinesGrid(),
            const SizedBox(height: 32),

            _buildSectionTitle(_activeFilterCategoryId == null ? "Cursos Destacados" : "Resultados para ti"),
            const SizedBox(height: 16),
            _buildFeaturedCollections(),
            const SizedBox(height: 32),
            
            _buildSectionHeader("Mi Lista de Deseos", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WishlistScreen()),
              ).then((_) => _loadData());
            }),
            const SizedBox(height: 16),
            _buildWishlistGrid(),
            const SizedBox(height: 40),
            
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- COMPONENTES AUXILIARES Y ESTADOS VACÍOS ---

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "U";
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return "U";
    if (parts.length == 1) return parts[0][0].toUpperCase();
    if (parts.length >= 3) return "${parts[0][0]}${parts[2][0]}".toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, size: 28),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Aura Academy",
              style: GoogleFonts.cinzel(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6366F1),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => setState(() => _selectedIndex = 3),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _profileStream,
            builder: (context, snapshot) {
              String initials = "U";
              String? avatarUrl;
              
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final profile = snapshot.data!.first;
                final name = profile['nombre_completo'] ?? "Usuario";
                initials = _getInitials(name);
                avatarUrl = profile['avatar_url'];
              } else {
                initials = _getInitials(_userName);
              }

              final bool hasAvatar = avatarUrl != null && avatarUrl.toString().trim().isNotEmpty;

              return Row(
                children: [
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final racha = snapshot.data!.first['racha_dias'] ?? 0;
                        if (racha == 0) return const SizedBox();
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFED7AA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_fire_department, color: Color(0xFFF97316), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                racha.toString(),
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF6366F1),
                    backgroundImage: hasAvatar ? NetworkImage(avatarUrl.toString()) : null,
                    child: !hasAvatar 
                        ? Text(
                            initials,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          )
                        : null,
                  ),
                ],
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hola, $_userName.",
          style: GoogleFonts.montserrat(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "¿Listo para explorar nuevas perspectivas hoy?",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() => _selectedIndex = 1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const TextField(
              enabled: false, // <--- Importante para que no abra el teclado aquí
              decoration: InputDecoration(
                hintText: "Buscar cursos, mentores...",
                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: const Text(
            "Ver Todas",
            style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildContinueLearningCard(Map<String, dynamic> actCourse) {
    final curso = actCourse['cursos'];
    final category = curso['categorias']?['nombre'] ?? "GENERAL";
    final pCent = actCourse['progreso_porcentaje'] ?? 0;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailScreen(courseId: curso['id']),
          ),
        ).then((_) => _loadData()); // recarga por si completó lecciones
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Image.network(
              curso['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?auto=format&fit=crop&q=80&w=800',
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.toString().toUpperCase(),
                  style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1), letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  curso['titulo'] ?? "Sin Título",
                  style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  curso['descripcion'] ?? curso['subtitulo'] ?? "Continúa con tus estudios...",
                  style: GoogleFonts.montserrat(fontSize: 14, color: const Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                // Ocultamos el progreso si es el instructor viendo su propio curso
                if (!(_isInstructor && curso['instructor_id'] == supabase.auth.currentUser?.id)) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("$pCent% COMPLETADO", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const Text("Continúa aquí", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: pCent / 100,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                const SizedBox(height: 24),
                
                // Botón Condicional: Si es el instructor del curso, mostramos "Gestionar"
                if (_isInstructor && curso['instructor_id'] == supabase.auth.currentUser?.id)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const InstructorPanelScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text("Gestionar Mi Curso", style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.analytics_rounded, size: 20),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        // Buscar lecciones completadas por el usuario
                        final userId = supabase.auth.currentUser?.id;
                        final completedRes = await supabase
                            .from('lecciones_completadas')
                            .select('leccion_id')
                            .eq('curso_id', curso['id'])
                            .eq('perfil_id', userId!);
                        
                        final completedIds = (completedRes as List).map((e) => e['leccion_id'].toString()).toSet();

                        // Buscar todos los módulos y sus lecciones ordenados
                        final modulesData = await supabase
                            .from('modulos')
                            .select('id, orden, lecciones(id, orden)')
                            .eq('curso_id', curso['id'])
                            .order('orden', ascending: true);

                        String? targetLessonId;
                        String? firstOverallLessonId;

                        for (var mod in modulesData) {
                          final lessonsList = List<Map<String, dynamic>>.from(mod['lecciones'] ?? []);
                          lessonsList.sort((a, b) => (a['orden'] ?? 0).compareTo(b['orden'] ?? 0));
                          
                          for (var l in lessonsList) {
                            final lId = l['id'].toString();
                            firstOverallLessonId ??= lId; // Guardar la primera por si acaso

                            if (!completedIds.contains(lId)) {
                              targetLessonId = lId;
                              break;
                            }
                          }
                          if (targetLessonId != null) break;
                        }

                        // Si todas están completadas, redirigimos a la primera de todas
                        targetLessonId ??= firstOverallLessonId;

                        if (targetLessonId != null && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LessonPlayerScreen(
                                courseId: curso['id'],
                                initialLessonId: targetLessonId!,
                              ),
                            ),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Este curso aún no tiene lecciones publicadas.")),
                          );
                        }
                      } catch (e) {
                        debugPrint("Error al reanudar lección: $e");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text("Reanudar Lección", style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.play_arrow_rounded, size: 20),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  String _formatStudyTime(double decimalHours) {
    int totalMinutes = (decimalHours * 60).round();
    if (totalMinutes < 60) {
      return "${decimalHours.toStringAsFixed(1)} h ($totalMinutes min)";
    }
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    if (minutes == 0) {
      return "$hours h";
    }
    return "$hours h $minutes min";
  }

  Widget _buildInstructorShortcutCard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const InstructorPanelScreen()),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF334155)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Panel de Instructor",
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Gestiona tus cursos y alumnos",
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorCoursesHorizontal() {
    return SizedBox(
      height: 290, // Aumentamos la altura para evitar el overflow de 7px
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _myCreatedCourses.length,
        clipBehavior: Clip.none,
        itemBuilder: (context, index) {
          final curso = _myCreatedCourses[index];
          final category = curso['categorias']?['nombre'] ?? "GENERAL";
          
          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.network(
                    curso['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&q=80&w=800',
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.toString().toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          color: const Color(0xFF6366F1), 
                          letterSpacing: 1.2
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        curso['titulo'] ?? "Sin Título",
                        style: GoogleFonts.montserrat(
                          fontSize: 15, 
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CourseDetailScreen(courseId: curso['id']),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Gestionar Curso", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyGoalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
              ),
              IconButton(
                onPressed: _showGoalSettings,
                icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                tooltip: "Ajustar Meta",
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("Meta Semanal (${_userMetaHours.toStringAsFixed(1)}h)", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
             _weeklyHours == 0.0 
               ? "Rastrea tu progreso real.\nTodavía no hay tiempo validado en sistema."
               : "Has estudiado ${_formatStudyTime(_weeklyHours)} esta semana. ¡Ya casi llegas!",
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
          ),
          const SizedBox(height: 32),
          Text("$_weeklyPercent%", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          Text("ALCANZADO", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWishlistGrid() {
    if (_wishlistCourses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.favorite_border_rounded, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(
              "Tu lista está vacía",
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Guarda los cursos que más te interesen\nhaciendo clic en el corazón.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 240,
          child: ListView.builder(
            controller: _wishlistController,
            scrollDirection: Axis.horizontal,
            itemCount: _wishlistCourses.length,
            itemBuilder: (context, index) {
              final course = _wishlistCourses[index];
              return Padding(
                padding: const EdgeInsets.only(right: 20),
                child: SizedBox(
                  width: 280,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CourseDetailScreen(courseId: course['id'])),
                      ).then((_) => _loadData());
                    },
                    child: _buildCourseItem(course),
                  ),
                ),
              );
            },
          ),
        ),
        if (_wishlistCourses.length > 1)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6366F1), size: 30),
                  onPressed: () {
                    _wishlistController.animateTo(
                      _wishlistController.offset + 300,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCourseItem(Map<String, dynamic> course) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.network(
                  course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=800',
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              if (course['en_oferta'] == true)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "OFERTA",
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course['titulo'] ?? "Sin Título",
                  style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "S/ ${course['precio']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1), fontSize: 16),
                    ),
                    if (course['en_oferta'] == true) ...[
                      const SizedBox(width: 8),
                      Text(
                        "S/ ${course['precio_original']}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDisciplinesGrid() {
    // Si el usuario ya eligió categorías, las usamos. 
    // De lo contrario, usamos una lista por defecto.
    final List<Map<String, dynamic>> disciplines = _userCategories.isNotEmpty
        ? _userCategories.map((cat) => {
            'id': cat['id'],
            'name': cat['nombre'],
            'icon': _getIconForCategory(cat['icono_nombre'] ?? cat['nombre']),
            'color': const Color(0xFFF1F5F9),
          }).toList()
        : [
            {'id': 'dev_id', 'name': 'Desarrollo', 'icon': Icons.code, 'color': const Color(0xFFF1F5F9)},
            {'id': 'ia_id', 'name': 'IA', 'icon': Icons.psychology, 'color': const Color(0xFFF1F5F9)},
            {'id': 'sec_id', 'name': 'Seguridad', 'icon': Icons.security, 'color': const Color(0xFFF1F5F9)},
            {'id': 'game_id', 'name': 'Juegos', 'icon': Icons.sports_esports, 'color': const Color(0xFFF1F5F9)},
          ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: disciplines.length,
      itemBuilder: (context, index) {
        final d = disciplines[index];
        final isSelected = _activeFilterCategoryId == d['id'];

        return InkWell(
          onTap: () {
            if (isSelected) {
              _loadFilteredCourses(null); // Quitar filtro
            } else {
              _loadFilteredCourses(d['id']); // Aplicar filtro
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEEF2FF) : d['color'], 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(
                    d['icon'] as IconData, 
                    size: 20, 
                    color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E293B)
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  d['name'] as String, 
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
                    color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF1E293B)
                  )
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturedCollections() {
    if (_featuredCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.auto_awesome_motion_rounded, 
        title: "Sin cursos destacados", 
        subtitle: "Estamos preparando el mejor contenido\npara ti. ¡Vuelve pronto!"
      );
    }

    return SizedBox(
      height: 340,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _featuredCourses.length,
        itemBuilder: (context, index) {
          final c = _featuredCourses[index];
          final rating = c['rating_promedio']?.toString() ?? "0.0";
          final profesorNombre = c['perfiles']?['nombre_completo'] ?? "Profesor Anonimo";
          
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CourseDetailScreen(courseId: c['id']),
                ),
              ).then((_) => _loadData()); // <--- FORZAR RECARGA AL VOLVER
            },
            child: Container(
              width: 260,
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        child: Image.network(
                          c['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&q=80&w=600',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(height: 150, color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(rating, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: GestureDetector(
                          onTap: () => _toggleWishlist(c['id'].toString()),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Icon(
                              _wishlistCourses.any((wc) => wc['id'].toString() == c['id'].toString()) 
                                ? Icons.favorite_rounded 
                                : Icons.favorite_outline_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      if (c['en_oferta'] == true)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)]),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Text(
                              "OFERTA",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['titulo'] ?? "Curso Sin Titulo",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: NetworkImage('https://ui-avatars.com/api/?name=${profesorNombre.replaceAll(" ", "+")}&background=random'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(profesorNombre, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(rating, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                            const SizedBox(width: 12),
                            const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF64748B), size: 14),
                            const SizedBox(width: 4),
                            Text("${c['vistas'] ?? 0}", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(width: 12),
                            const Icon(Icons.favorite_rounded, color: Colors.red, size: 12),
                            const SizedBox(width: 4),
                            Text("${c['likes_count'] ?? 0}", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("S/ ${c['precio'] ?? '0.00'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF6366F1))),
                                if (c['en_oferta'] == true) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    "S/ ${c['precio_original'] ?? ''}",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough),
                                  ),
                                ],
                              ],
                            ),
                            const Text("Ver Curso", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForCategory(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'code':
      case 'desarrollo':
        return Icons.code;
      case 'pen-nib':
      case 'diseño':
        return Icons.draw;
      case 'briefcase':
      case 'negocios':
        return Icons.business_center;
      case 'chart-bar':
      case 'marketing':
        return Icons.bar_chart;
      case 'music':
      case 'musica':
        return Icons.music_note;
      case 'camera':
      case 'fotografia':
        return Icons.camera_alt;
      case 'language':
      case 'idiomas':
        return Icons.language;
      case 'shield-halved':
      case 'ciberseguridad':
        return Icons.security;
      case 'brain':
      case 'inteligencia artificial':
      case 'ia':
        return Icons.psychology;
      case 'link':
      case 'blockchain':
        return Icons.link;
      case 'gamepad':
      case 'videojuegos':
        return Icons.sports_esports;
      case 'dollar-sign':
      case 'finanzas':
        return Icons.attach_money;
      case 'heart-pulse':
      case 'salud y bienestar':
        return Icons.favorite;
      case 'pen-fancy':
      case 'escritura':
        return Icons.edit;
      case 'database':
      case 'ciencia de datos':
        return Icons.storage;
      case 'users':
      case 'liderazgo':
        return Icons.group;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      elevation: 0,
      backgroundColor: Colors.white,
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() => _selectedIndex = index);
        // Si el usuario vuelve al INICIO, refrescamos los datos para ver cambios (como el nombre)
        if (index == 0) {
          _loadData();
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF6366F1),
      unselectedItemColor: const Color(0xFF94A3B8),
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "INICIO"),
        BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: "BUSCAR"),
        BottomNavigationBarItem(icon: Icon(Icons.play_circle_fill_rounded), label: "MIS CURSOS"),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "PERFIL"),
      ],
    );
  }
}





