import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:aura_academy/screens/instructor/course_structure_screen.dart';
import 'package:aura_academy/screens/courses/course_detail_screen.dart';

class CreateCourseScreen extends StatefulWidget {
  final String? courseId;
  const CreateCourseScreen({super.key, this.courseId});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final supabase = Supabase.instance.client;
  
  // Controllers
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _subtituloController = TextEditingController(); // Descripción breve
  final TextEditingController _descripcionController = TextEditingController(); // Descripción larga (Acerca de)
  final TextEditingController _duracionController = TextEditingController(); // Duración en texto
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _precioOriginalController = TextEditingController();
  
  bool _enOferta = false;
  
  String _selectedNivel = 'Principiante';
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categorias = [];
  bool _isLoading = false;
  String? _courseId; 
  String? _existingThumbnailUrl; // URL si ya existe en la BD
  
  // Imagen de Miniatura
  
  Uint8List? _imageBytes;
  String? _imageExt;

  @override
  void initState() {
    super.initState();
    _courseId = widget.courseId;
    _fetchCategorias();
    if (_courseId != null) {
      _loadCourseData();
    }
  }

  Future<void> _loadCourseData() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('cursos')
          .select('*')
          .eq('id', _courseId!)
          .single();

      setState(() {
        _tituloController.text = data['titulo'] ?? '';
        _subtituloController.text = data['subtitulo'] ?? '';
        _descripcionController.text = data['descripcion'] ?? '';
        _duracionController.text = data['duracion_texto'] ?? '';
        _precioController.text = data['precio']?.toString() ?? '';
        _precioOriginalController.text = data['precio_original']?.toString() ?? '';
        _enOferta = data['en_oferta'] ?? false;
        _selectedCategoryId = data['categoria_id'];
        _selectedNivel = data['nivel'] ?? 'Principiante';
        _existingThumbnailUrl = data['thumbnail_url'];
      });
    } catch (e) {
      debugPrint("Error cargando datos del curso: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCategorias() async {
    try {
      final data = await supabase.from('categorias').select('id, nombre');
      setState(() {
        _categorias = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint("Error cargando categorías: $e");
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
      setState(() {
        _imageBytes = result.files.first.bytes;
        _imageExt = result.files.first.extension ?? 'png';
      });
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageBytes == null) return null;

    try {
      final fileExt = _imageExt;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/$fileName';

      await supabase.storage.from('miniaturas').uploadBinary(
        filePath,
        _imageBytes!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final String publicUrl = supabase.storage.from('miniaturas').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      debugPrint("Error subiendo imagen: $e");
      return null;
    }
  }

  Future<bool> _publicarCurso() async {
    if (_tituloController.text.isEmpty || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa los campos obligatorios')),
      );
      return false;
    }

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      // 1. Subir imagen primero (si existe)
      String? thumbnailUrl;
      if (_imageBytes != null) {
        thumbnailUrl = await _uploadImage(user.id);
      }

      // 2. Insertar ó Actualizar curso (Upsert)
      final courseData = {
        'titulo': _tituloController.text,
        'subtitulo': _subtituloController.text,
        'descripcion': _descripcionController.text,
        'duracion_texto': _duracionController.text,
        'categoria_id': _selectedCategoryId,
        'instructor_id': user.id,
        'precio': double.tryParse(_precioController.text) ?? 0.0,
        'precio_original': double.tryParse(_precioOriginalController.text) ?? (double.tryParse(_precioController.text) ?? 0.0),
        'en_oferta': _enOferta,
        'nivel': _selectedNivel,
        'thumbnail_url': thumbnailUrl ?? _existingThumbnailUrl ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=800',
        'es_destacado': false,
        'estado': 'Publicado', // Al presionar Publicar, cambia el estado
      };

      final response = await supabase
          .from('cursos')
          .upsert(
            _courseId != null 
              ? {...courseData, 'id': _courseId} 
              : courseData
          )
          .select()
          .single();

      setState(() {
        _courseId = response['id'];
      });

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4F46E5)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Crear Nuevo Curso",
          style: GoogleFonts.montserrat(
            color: const Color(0xFF4F46E5),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              if (_courseId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseDetailScreen(courseId: _courseId!),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Guarda tu curso primero (ponle un título) para verlo en detalle')),
                );
              }
            },
            child: const Text("Vista Previa", style: TextStyle(color: Color(0xFF6366F1))),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniatura
            Text("MINIATURA DEL CURSO", 
              style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 12),
            _buildImageUpload(),
            
            const SizedBox(height: 32),
            
            // Título
            _buildLabel("Título del Curso"),
            _buildTextField(_tituloController, "Ej. Masterclass en Diseño UX"),
            
            const SizedBox(height: 24),
            
            // Categoría
            _buildLabel("Categoría"),
            _buildCategoryDropdown(),
            
            const SizedBox(height: 24),
            
            // Descripción Breve
            _buildLabel("Descripción Breve (Resumen)"),
            _buildTextField(_subtituloController, "Ej. Domina el diseño de interfaces en solo 5 semanas.", maxLines: 2),
            
            const SizedBox(height: 24),

            // Descripción Detallada
            _buildLabel("Descripción Detallada (Acerca del curso)"),
            _buildTextField(_descripcionController, "Aquí puedes detallar los objetivos, el temario y para quién va dirigido el curso...", maxLines: 6),
            
            const SizedBox(height: 24),

            // Duración
            _buildLabel("Duración Estimada"),
            _buildTextField(_duracionController, "Ej. 10 horas de video, 5 semanas, etc."),
            
            const SizedBox(height: 24),
            
            // Nivel
            _buildLabel("Nivel"),
            _buildNivelSelector(),
            
            const SizedBox(height: 32),

            // Precio y Ofertas
            _buildLabel("Precio Final de Venta (S/)"),
            _buildPriceField(),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _enOferta ? const Color(0xFFF5F3FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _enOferta ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Activar Oferta", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Muestra un badge de oferta y precio tachado", style: TextStyle(fontSize: 12)),
                    value: _enOferta,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (val) => setState(() => _enOferta = val),
                  ),
                  if (_enOferta) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildLabel("Precio Original (S/)"),
                    _buildOriginalPriceField(),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Siguiente (Visual)
            GestureDetector(
              onTap: () async {
                // Auto-guardar primero para tener un ID
                if (_tituloController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ponle un título al curso antes de configurar la estructura')),
                  );
                  return;
                }
                
                await _publicarCurso(); // Esto hace el upsert y llena _courseId
                
                if (_courseId != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseStructureScreen(
                        courseId: _courseId!,
                        courseTitle: _tituloController.text,
                      ),
                    ),
                  );
                }
              },
              child: _buildNextStepCard(),
            ),
            
            const SizedBox(height: 100), // Espacio para botones
          ],
        ),
      ),
      bottomSheet: _buildBottomButtons(),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
    );
  }

  Widget _buildImageUpload() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          image: _imageBytes != null 
            ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
            : (_existingThumbnailUrl != null 
                ? DecorationImage(image: NetworkImage(_existingThumbnailUrl!), fit: BoxFit.cover)
                : null),
        ),
        child: CustomPaint(
          painter: DashedRectPainter(color: Colors.grey[400]!, gap: 6),
          child: (_imageBytes == null && _existingThumbnailUrl == null) 
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_rounded, size: 48, color: Color(0xFF6366F1)),
                  const SizedBox(height: 8),
                  Text("Recomendado: 1280 x 720 px", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Subir Imagen", style: TextStyle(color: Colors.white)),
                  )
                ],
              )
            : Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(Icons.edit, color: Colors.white, size: 32),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: const Text("Seleccionar categoría", style: TextStyle(color: Color(0xFF94A3B8))),
          value: _selectedCategoryId,
          items: _categorias.map((cat) {
            return DropdownMenuItem<String>(
              value: cat['id'].toString(),
              child: Text(cat['nombre']),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedCategoryId = val),
        ),
      ),
    );
  }

  Widget _buildNivelSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: ['Principiante', 'Intermedio', 'Avanzado'].map((nivel) {
          bool isSelected = _selectedNivel == nivel;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedNivel = nivel),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                ),
                child: Center(
                  child: Text(
                    nivel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriceField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text("S/ ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: TextField(
              controller: _precioController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: "Ej. 49.99",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          const Text("PEN", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildOriginalPriceField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Text("S/ ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Expanded(
            child: TextField(
              controller: _precioOriginalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough),
              decoration: const InputDecoration(
                hintText: "Ej. 149.99",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Color(0xFF94A3B8), decoration: TextDecoration.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(24),
        border: const Border(left: BorderSide(color: Color(0xFF6366F1), width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Siguiente: Estructura del Curso", 
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF6366F1))),
                const Text("Módulos, lecciones y recursos", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF6366F1)),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.save, color: Color(0xFF1E293B)),
                Text("Borrador", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading 
                ? null 
                : () async {
                    bool success = await _publicarCurso();
                    if (success && mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('¡Curso publicado exitosamente! 🚀')),
                      );
                    }
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch, color: Colors.white),
                      SizedBox(width: 8),
                      Text("Publicar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  Color color;
  double gap;
  DashedRectPainter({required this.color, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(24)));

    Path dashPath = Path();
    for (PathMetric pathMetric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < pathMetric.length) {
        if (draw) {
          dashPath.addPath(pathMetric.extractPath(distance, distance + gap), Offset.zero);
        }
        distance += gap;
        draw = !draw;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}







