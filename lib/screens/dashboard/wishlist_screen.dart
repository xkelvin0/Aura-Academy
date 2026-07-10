import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_academy/screens/courses/course_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _wishlist = [];

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final results = await supabase
          .from('lista_deseos')
          .select('*, cursos(*, perfiles(nombre_completo))')
          .eq('perfil_id', user.id)
          .order('fecha_agregado', ascending: false);

      setState(() {
        _wishlist = (results as List).map((e) => e['cursos'] as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando lista de deseos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Mi Lista de Deseos",
          style: GoogleFonts.montserrat(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF64748B)),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _wishlist.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border_rounded, size: 80, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text("Tu lista está vacía", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 8),
          const Text("Explora cursos y dales al corazón\npara guardarlos aquí.", textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildList() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _wishlist.length,
      itemBuilder: (context, index) {
        final course = _wishlist[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CourseDetailScreen(courseId: course['id'])),
            ).then((_) => _loadWishlist());
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.network(
                          course['thumbnail_url'] ?? 'https://via.placeholder.com/600x400.png',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      if (course['en_oferta'] == true)
                        Positioned(
                          top: 8,
                          left: 8,
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
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['titulo'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text("S/ ${course['precio']}", style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 13)),
                          if (course['en_oferta'] == true) ...[
                            const SizedBox(width: 6),
                            Text(
                              "S/ ${course['precio_original']}",
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
      },
    );
  }
}





