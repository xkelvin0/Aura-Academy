import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:aura_academy/screens/courses/course_detail_screen.dart';
import 'package:aura_academy/screens/dashboard/dashboard_screen.dart';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allCourses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  bool _isLoading = true;
  Timer? _debounce;
  List<String> _wishlistIds = []; // <--- IDs de cursos favoritos

  List<Map<String, dynamic>> _dbCategories = [];
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // Sincronización Global
    DashboardScreen.courseUpdateController.stream.listen((_) {
      if (mounted) _loadInitialData();
    });

    DashboardScreen.searchStreamController.stream.listen((query) {
      if (mounted) {
        _searchController.text = query;
        _performSearch(query);
      }
    });
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadCategories(),
      _loadAllCourses(),
      _loadWishlist(),
    ]);
  }

  Future<void> _loadCategories() async {
    try {
      final res = await supabase.from('categorias').select('*');
      if (mounted) {
        setState(() {
          _dbCategories = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint("Error cargando categorías: $e");
    }
  }

  Future<void> _loadAllCourses() async {
    try {
      final res = await supabase
          .from('cursos')
          .select('*, perfiles(nombre_completo)') 
          .order('fecha_creacion', ascending: false);
      
      if (mounted) {
        setState(() {
          _allCourses = List<Map<String, dynamic>>.from(res);
          _filteredCourses = _allCourses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando catálogo: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWishlist() async {
    try {
      final user = supabase.auth.currentUser;
      debugPrint("🔍 Cargando wishlist para usuario: ${user?.id}");
      if (user == null) return;

      final res = await supabase
          .from('lista_deseos')
          .select('curso_id')
          .eq('perfil_id', user.id);
      
      if (mounted) {
        setState(() {
          _wishlistIds = (res as List).map((e) => e['curso_id'].toString()).toList();
          debugPrint("✅ Wishlist cargada: $_wishlistIds");
        });
      }
    } catch (e) {
      debugPrint("❌ Error wishlist: $e");
    }
  }

  Future<void> _toggleWishlist(String courseId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final isFavorite = _wishlistIds.contains(courseId);
    final course = _allCourses.firstWhere((c) => c['id'] == courseId);
    
    // BLOQUEO DE AUTO-LIKE
    if (course['instructor_id'] == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("👨‍🏫 Como instructor, no puedes darte auto-like."),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
      return;
    }

    try {
      if (isFavorite) {
        await supabase
            .from('lista_deseos')
            .delete()
            .eq('perfil_id', user.id)
            .eq('curso_id', courseId);
        
        setState(() => _wishlistIds.remove(courseId));
      } else {
        await supabase.from('lista_deseos').insert({
          'perfil_id': user.id,
          'curso_id': courseId,
        });

        setState(() => _wishlistIds.add(courseId));
      }
      // RECARGAR para que el contador de likes se actualice desde la DB
      _loadAllCourses();
      // NOTIFICAR A LAS DEMÁS PESTAÑAS
      DashboardScreen.courseUpdateController.add(null);
    } catch (e) {
      debugPrint("Error toggle wishlist: $e");
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  void _performSearch(String query) {
    setState(() {
      _filteredCourses = _allCourses.where((course) {
        // 1. Verificar Categoría
        final matchesCategory = _selectedCategoryId == null || 
            course['categoria_id'] == _selectedCategoryId;

        if (!matchesCategory) return false;

        // 2. Verificar Texto
        final catName = _dbCategories.firstWhere(
          (c) => c['id'] == _selectedCategoryId, 
          orElse: () => {'nombre': ''}
        )['nombre'].toString().toLowerCase();

        final isQueryJustCategoryName = query.toLowerCase() == catName;

        if (query.isEmpty || isQueryJustCategoryName) return true;

        final matchesText = 
            (course['titulo']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (course['subtitulo']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (course['descripcion']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false);
        
        return matchesText;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAllCourses,
                color: const Color(0xFF6366F1),
                child: _isLoading && _allCourses.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Explorar Catálogo",
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Busca cursos, temas o lenguajes...",
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _selectedCategoryId = null);
                        _performSearch("");
                      },
                    )
                  : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final String query = _searchController.text.trim();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryHorizontalList(),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            query.isEmpty && _selectedCategoryId == null ? "Todos los Cursos" : "Resultados de búsqueda",
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _filteredCourses.isEmpty
            ? _buildNoResults(query)
            : GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 250, // Altura optimizada para evitar espacio vacío
                ),
                itemCount: _filteredCourses.length,
                itemBuilder: (context, index) => _buildVerticalCourseCard(_filteredCourses[index]),
              ),
        ),
      ],
    );
  }

  Widget _buildCategoryHorizontalList() {
    if (_dbCategories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Categorías",
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _dbCategories.length,
            itemBuilder: (context, index) {
              final cat = _dbCategories[index];
              final isSelected = _selectedCategoryId == cat['id'];
              final color = _getColorForCategory(cat['nombre']);

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FilterChip(
                  label: Text(cat['nombre']),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (isSelected) {
                        _selectedCategoryId = null;
                        _searchController.clear();
                      } else {
                        _selectedCategoryId = cat['id'];
                        _searchController.text = cat['nombre'];
                      }
                    });
                    _performSearch(_searchController.text);
                  },
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                  selectedColor: color,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? color : const Color(0xFFE2E8F0)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No hay resultados para tu búsqueda",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalCourseCard(Map<String, dynamic> c) {
    final String courseId = c['id'].toString();
    final bool isFavorite = _wishlistIds.contains(courseId);
    final String rating = c['rating_promedio']?.toString() ?? "0.0";
    final String profesorNombre = c['perfiles']?['nombre_completo'] ?? "Instructor";

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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen con corazón y rating
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    c['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&q=80&w=400',
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 110, color: Colors.grey[100], child: const Icon(Icons.image_not_supported)),
                  ),
                ),
                // Corazón
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () => _toggleWishlist(courseId),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                // Rating arriba a la derecha
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                        const SizedBox(width: 2),
                        Text(rating, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                // Badge de Oferta abajo a la izquierda
                if (c['en_oferta'] == true)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "OFERTA",
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['titulo'] ?? "Sin Título",
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profesorNombre,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Fila de Estadísticas (Vistas y Likes)
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF94A3B8), size: 12),
                      const SizedBox(width: 4),
                      Text("${c['vistas'] ?? 0}", style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      const SizedBox(width: 8),
                      const Icon(Icons.favorite_rounded, color: Colors.red, size: 10),
                      const SizedBox(width: 2),
                      Text("${c['likes_count'] ?? 0}", style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "S/ ${c['precio']}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1), fontSize: 14),
                      ),
                      if (c['en_oferta'] == true) ...[
                        const SizedBox(width: 6),
                        Text(
                          "S/ ${c['precio_original']}",
                          style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForCategory(String name) {
    name = name.toLowerCase();
    if (name.contains('desarrollo')) return const Color(0xFF6366F1);
    if (name.contains('ia')) return const Color(0xFF8B5CF6);
    if (name.contains('diseño')) return const Color(0xFFEC4899);
    if (name.contains('negocios')) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }
}





