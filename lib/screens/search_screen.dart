import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'course_detail_screen.dart';
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

  final List<Map<String, dynamic>> _categories = [
    {'id': 'dev_id', 'nombre': 'Desarrollo', 'icon': FontAwesomeIcons.code, 'color': const Color(0xFF6366F1)},
    {'id': 'ia_id', 'nombre': 'IA', 'icon': FontAwesomeIcons.brain, 'color': const Color(0xFF8B5CF6)},
    {'id': 'design_id', 'nombre': 'Diseño', 'icon': FontAwesomeIcons.penNib, 'color': const Color(0xFFEC4899)},
    {'id': 'biz_id', 'nombre': 'Negocios', 'icon': FontAwesomeIcons.briefcase, 'color': const Color(0xFFF59E0B)},
  ];

  @override
  void initState() {
    super.initState();
    _loadAllCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
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
      debugPrint("DEBUG: Error cargando catálogo con join: $e");
      // Fallback: intentar cargar sin nombres si el join falla
      try {
        final res = await supabase.from('cursos').select('*').order('fecha_creacion', ascending: false);
        if (mounted) {
          setState(() {
            _allCourses = List<Map<String, dynamic>>.from(res);
            _filteredCourses = _allCourses;
            _isLoading = false;
          });
        }
      } catch (e2) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {}); 

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _filteredCourses = _allCourses);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await supabase
          .from('cursos')
          .select('*, perfiles(nombre_completo)')
          .ilike('titulo', '%$query%');

      if (mounted) {
        setState(() {
          _filteredCourses = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("DEBUG: Error buscando con join: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAllCourses,
                color: const Color(0xFF6366F1),
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
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
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
                        _onSearchChanged("");
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
    
    if (query.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          _buildCategoryGrid(),
          const SizedBox(height: 32),
          Text(
            "Todos los Cursos",
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          if (_allCourses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  "Aún no hay cursos publicados.",
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ),
            )
          else
            ..._allCourses.map((c) => _buildWideCourseCard(c)).toList(),
          const SizedBox(height: 24),
        ],
      );
    }

    if (_filteredCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No encontramos resultados para '$query'",
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _onSearchChanged("");
              },
              child: const Text("Limpiar Búsqueda", style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 8),
        ..._filteredCourses.map((c) => _buildWideCourseCard(c)).toList(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Categorías Populares",
          style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: InkWell(
                onTap: () {
                  _searchController.text = cat['nombre'];
                  _performSearch(cat['nombre']);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cat['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(cat['icon'], size: 16, color: cat['color']),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        cat['nombre'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWideCourseCard(Map<String, dynamic> c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseDetailScreen(courseId: c['id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  c['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&q=80&w=200',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 100, height: 100, color: Colors.grey[100], child: const Icon(Icons.image_not_supported)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c['en_oferta'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("OFERTA", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 9)),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      c['titulo'] ?? "Sin Título",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text("Instructor", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text("S/ ${c['precio']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                        if (c['en_oferta'] == true) ...[
                          const SizedBox(width: 8),
                          Text("S/ ${c['precio_original']}", style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}
