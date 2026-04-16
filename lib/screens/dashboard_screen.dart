import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'profile_screen.dart';
import 'category_selection_screen.dart';
import 'course_detail_screen.dart';
import 'search_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;
  int _selectedIndex = 0;
  String _userName = "Estudiante";
  bool _isLoading = true;

  // Variables Dinámicas Reales
  List<Map<String, dynamic>> _enrollments = [];
  List<Map<String, dynamic>> _featuredCourses = [];
  double _weeklyHours = 0.0;
  int _weeklyPercent = 0;
  List<Map<String, dynamic>> _userCategories = [];
  String? _activeFilterCategoryId; // Filtro actual
  bool _isFiltering = false; // Estado de carga del filtro

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // 1. Obtener Nombre del Perfil
        final profileResponse = await supabase
            .from('perfiles')
            .select('nombre_completo')
            .eq('id', user.id)
            .maybeSingle();
        
        // 2. Obtener Inscripciones en progreso (El card principal)
        final enrollmentsRes = await supabase
            .from('inscripciones')
            .select('*, cursos(*, categorias(nombre))')
            .eq('perfil_id', user.id)
            .eq('en_progreso', true)
            .order('ultima_vez_visto', ascending: false);
            
        // 3. Obtener Cursos Destacados de la Tienda global
        final featuredRes = await supabase
            .from('cursos')
            .select('*, perfiles(nombre_completo)') 
            .eq('es_destacado', true)
            .limit(10);
            
        // 4. Obtener Meta Semanal de este usuario
        final metaRes = await supabase
            .from('metas_semanales')
            .select('*')
            .eq('perfil_id', user.id)
            .maybeSingle(); // Puede no existir aún esta semana

        // 5. Obtener Categorías Seleccionadas por el usuario
        final userCatsRes = await supabase
            .from('perfil_categorias')
            .select('categorias(*)')
            .eq('perfil_id', user.id);

        if (mounted) {
          setState(() {
            _userName = profileResponse?['nombre_completo'] ?? 
                        user.userMetadata?['full_name'] ?? 
                        user.email?.split('@')[0] ??
                        "Usuario";
            _enrollments = List<Map<String, dynamic>>.from(enrollmentsRes);
            _featuredCourses = List<Map<String, dynamic>>.from(featuredRes);
            
            if (metaRes != null) {
              _weeklyHours = double.parse(metaRes['horas_estudiadas'].toString());
              _weeklyPercent = metaRes['porcentaje_alcanzado'] ?? 0;
            } else {
              _weeklyHours = 0.0;
              _weeklyPercent = 0;
            }
            
            // Mapear categorías del usuario
            if (userCatsRes != null) {
              _userCategories = (userCatsRes as List)
                  .map((item) => item['categorias'] as Map<String, dynamic>)
                  .toList();
            }
            _isLoading = false;
          });

          // VERIFICACIÓN CRÍTICA: Si no hay categorías, mandamos a elegir
          if (_userCategories.isEmpty && mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const CategorySelectionScreen()),
              (route) => false,
            );
          }
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
      var query = supabase
          .from('cursos')
          .select('*, perfiles(nombre_completo)');

      if (categoryId != null) {
        query = query.eq('categoria_id', categoryId);
      } else {
        query = query.eq('es_destacado', true);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pages = [
      _buildHomeContent(), 
      const SearchScreen(), 
      const Center(child: Text("Mis Aprendizajes")), 
      const ProfileScreen(), 
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeContent() {
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
            
            _buildSectionTitle("Principales Disciplinas"),
            const SizedBox(height: 16),
            _buildDisciplinesGrid(),
            const SizedBox(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSectionTitle(
                    _activeFilterCategoryId == null 
                      ? "Colecciones Destacadas" 
                      : "Resultados del Filtro"
                  )
                ),
                if (_activeFilterCategoryId != null)
                  TextButton(
                    onPressed: () => _loadFilteredCourses(null),
                    child: const Text("Limpiar", style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                  )
                else
                  TextButton(
                    onPressed: () {},
                    child: const Text("Ver Todas", style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isFiltering)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ))
            else if (_featuredCourses.isEmpty)
               _buildEmptyState(
                 icon: Icons.auto_awesome, 
                 title: "No hay cursos aquí todavía", 
                 subtitle: "Intenta con otra disciplina o limpia el filtro."
               )
            else
               _buildFeaturedCollections(),
            
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
            const Icon(Icons.menu_rounded, size: 28),
            const SizedBox(width: 16),
            Text(
              "Cognitive Gallery",
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => setState(() => _selectedIndex = 3),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF6366F1),
            child: Text(
              _getInitials(_userName),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
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
            color: const Color(0xFF1E293B),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: "Buscar cursos, mentores...",
              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              icon: Icon(Icons.search, color: Color(0xFF94A3B8)),
            ),
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
    
    return Container(
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
                  style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Text(
                  curso['descripcion'] ?? curso['subtitulo'] ?? "Continúa con tus estudios...",
                  style: GoogleFonts.montserrat(fontSize: 14, color: const Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$pCent% COMPLETADO", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    // Se pueden cruzar las lecciones más adelante
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {},
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          const Text("Meta Semanal", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
             _weeklyHours == 0.0 
               ? "Rastrea tu progreso real.\nTodavía no hay tiempo validado en sistema."
               : "Has estudiado $_weeklyHours horas esta semana. ¡Ya casi llegas!",
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
          ),
          const SizedBox(height: 32),
          Text("$_weeklyPercent%", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          Text("ALCANZADO", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold)),
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
            {'id': 'dev_id', 'name': 'Desarrollo', 'icon': FontAwesomeIcons.code, 'color': const Color(0xFFF1F5F9)},
            {'id': 'ia_id', 'name': 'IA', 'icon': FontAwesomeIcons.brain, 'color': const Color(0xFFF1F5F9)},
            {'id': 'sec_id', 'name': 'Seguridad', 'icon': FontAwesomeIcons.shieldHalved, 'color': const Color(0xFFF1F5F9)},
            {'id': 'game_id', 'name': 'Juegos', 'icon': FontAwesomeIcons.gamepad, 'color': const Color(0xFFF1F5F9)},
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
    return SizedBox(
      height: 300,
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
              );
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
                      if (c['en_oferta'] == true)
                        Positioned(
                          top: 12,
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
        return FontAwesomeIcons.code;
      case 'pen-nib':
      case 'diseño':
        return FontAwesomeIcons.penNib;
      case 'briefcase':
      case 'negocios':
        return FontAwesomeIcons.briefcase;
      case 'chart-bar':
      case 'marketing':
        return FontAwesomeIcons.chartBar;
      case 'music':
      case 'musica':
        return FontAwesomeIcons.music;
      case 'camera':
      case 'fotografia':
        return FontAwesomeIcons.camera;
      case 'language':
      case 'idiomas':
        return FontAwesomeIcons.language;
      case 'shield-halved':
      case 'ciberseguridad':
        return FontAwesomeIcons.shieldHalved;
      case 'brain':
      case 'inteligencia artificial':
      case 'ia':
        return FontAwesomeIcons.brain;
      case 'link':
      case 'blockchain':
        return FontAwesomeIcons.link;
      case 'gamepad':
      case 'videojuegos':
        return FontAwesomeIcons.gamepad;
      case 'dollar-sign':
      case 'finanzas':
        return FontAwesomeIcons.dollarSign;
      case 'heart-pulse':
      case 'salud y bienestar':
        return FontAwesomeIcons.heartPulse;
      case 'pen-fancy':
      case 'escritura':
        return FontAwesomeIcons.penFancy;
      case 'database':
      case 'ciencia de datos':
        return FontAwesomeIcons.database;
      case 'users':
      case 'liderazgo':
        return FontAwesomeIcons.users;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      elevation: 0,
      backgroundColor: Colors.white,
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
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
