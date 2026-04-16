import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dashboard_screen.dart';

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() => _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];
  final Set<String> _selectedCategoryIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await supabase.from('categorias').select().order('nombre');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSelection() async {
    if (_selectedCategoryIds.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona exactamente 4 opciones')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      
      // Limpiar selecciones previas por si acaso
      await supabase.from('perfil_categorias').delete().eq('perfil_id', userId);
      
      // Insertar nuevas
      final inserts = _selectedCategoryIds.map((id) => {
        'perfil_id': userId,
        'categoria_id': id,
      }).toList();
      
      await supabase.from('perfil_categorias').insert(inserts);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error saving categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar tus preferencias: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  IconData _getIcon(String? iconName) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Personaliza tu experiencia',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6366F1),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¿Qué quieres aprender?',
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Elige exactamente 4 categorías que te interesen para personalizar tu catálogo.',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final id = cat['id'];
                        final isSelected = _selectedCategoryIds.contains(id);
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCategoryIds.remove(id);
                              } else {
                                if (_selectedCategoryIds.length < 4) {
                                  _selectedCategoryIds.add(id);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ya has seleccionado 4 opciones. Deselecciona una para cambiar.'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                                width: 2,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                )
                              ] : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getIcon(cat['icono_nombre'] ?? cat['nombre']),
                                  size: 32,
                                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  cat['nombre'],
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _selectedCategoryIds.length == 4 && !_isSaving
                            ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                            : [Colors.grey.shade300, Colors.grey.shade400],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _selectedCategoryIds.length == 4 && !_isSaving ? [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ] : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (_selectedCategoryIds.length == 4 && !_isSaving) ? _saveSelection : null,
                        borderRadius: BorderRadius.circular(18),
                        child: Center(
                          child: _isSaving 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _selectedCategoryIds.length == 4 
                                  ? 'Comenzar mi aventura' 
                                  : 'Elige ${_selectedCategoryIds.length}/4 categorías',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
