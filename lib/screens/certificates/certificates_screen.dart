import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:aura_academy/screens/certificates/certificate_detail_screen.dart'; // <--- Nuevo import

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _certificates = [];
  bool _isLoading = true;
  String _studentName = "Estudiante"; // <--- Nuevo: Almacenar nombre

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final res = await supabase
          .from('certificados')
          .select('*, cursos(titulo, thumbnail_url)')
          .eq('perfil_id', user.id)
          .order('fecha_emision', ascending: false);

      // 2. Obtener nombre del perfil
      final profileRes = await supabase
          .from('perfiles')
          .select('nombre_completo')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _certificates = List<Map<String, dynamic>>.from(res);
          _studentName = profileRes?['nombre_completo'] ?? "Estudiante";
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando certificados: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Mis Certificados",
          style: GoogleFonts.montserrat(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _certificates.isEmpty
              ? _buildEmptyState()
              : _buildCertificatesGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.workspace_premium, size: 64, color: const Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 24),
          Text(
            "Aún no hay certificados",
            style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Completa tus cursos al 100% para desbloquear tus certificados oficiales.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatesGrid() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _certificates.length,
      itemBuilder: (context, index) {
        final cert = _certificates[index];
        final curso = cert['cursos'];
        final fecha = cert['fecha_emision'] != null 
            ? DateTime.parse(cert['fecha_emision'].toString())
            : DateTime.now();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CertificateDetailScreen(
                  certificate: cert,
                  studentName: _studentName,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: const Color(0xFFEEF2FF), width: 1),
            ),
            child: Column(
              children: [
                Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.workspace_premium, color: Color(0xFF6366F1), size: 32),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              curso['titulo'] ?? "Certificado de Curso",
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Emitido el ${fecha.day}/${fecha.month}/${fecha.year}",
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "ID: ${cert['hash_validacion']?.toString().substring(0, 12).toUpperCase() ?? cert['id'].toString().substring(0, 8).toUpperCase()}",
                              style: GoogleFonts.sourceCodePro(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CertificateDetailScreen(
                            certificate: cert,
                            studentName: _studentName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: const Text("Ver Certificado Premium"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(color: Color(0xFFEEF2FF)),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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





