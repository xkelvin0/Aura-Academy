import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CertificateDetailScreen extends StatefulWidget {
  final Map<String, dynamic> certificate;
  final String studentName;

  const CertificateDetailScreen({
    super.key,
    required this.certificate,
    required this.studentName,
  });

  @override
  State<CertificateDetailScreen> createState() => _CertificateDetailScreenState();
}

class _CertificateDetailScreenState extends State<CertificateDetailScreen> {
  final GlobalKey _globalKey = GlobalKey();

  Future<void> _captureAndShareImage() async {
    try {
      // 1. Mostrar feedback al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Generando imagen de alta calidad... 📸")),
      );

      // 2. Capturar el widget
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); // 3.0 para alta resolución
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 3. Guardar temporalmente para compartir
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/Certificado_Aura.png').create();
      await imagePath.writeAsBytes(pngBytes);

      // 4. Compartir/Guardar
      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: '¡Mira mi nuevo certificado de Aura Academy! 🎓🏆',
      );
    } catch (e) {
      debugPrint("Error al capturar imagen: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al generar la imagen")),
      );
    }
  }

  void _showQrModal(BuildContext context, String hash) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que la ventana crezca según el contenido
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SingleChildScrollView( // Evita el desborde en pantallas pequeñas
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Escanea para validar",
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enlace oficial de Aura Academy",
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: QrImageView(
                data: "https://silver-axolotl-4db970.netlify.app/?id=$hash",
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "ID: $hash",
              style: GoogleFonts.sourceCodePro(
                color: const Color(0xFF10B981),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Cerrar"),
            ),
          ],
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final curso = widget.certificate['cursos'];
    final fecha = widget.certificate['fecha_emision'] != null
        ? DateTime.parse(widget.certificate['fecha_emision'].toString())
        : DateTime.now();
    final hash = widget.certificate['hash_validacion'] ?? "VERIFY-AURA-HASH-ID";

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: _captureAndShareImage,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // DIPLOMA CONTAINER (CAPTURABLE)
            RepaintBoundary(
              key: _globalKey,
              child: AspectRatio(
                aspectRatio: 1.414,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      _buildBorderDecoration(),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: 400,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.workspace_premium, size: 48, color: Color(0xFFD4AF37)), 
                                  const SizedBox(height: 12),
                                  Text(
                                    "CERTIFICADO DE EXCELENCIA",
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "AURA ACADEMY",
                                    style: GoogleFonts.cinzel(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  Text(
                                    "Otorgado a:",
                                    style: GoogleFonts.italiana(
                                      fontSize: 18,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.studentName.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  Text(
                                    "Por completar satisfactoriamente el curso de:",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.italiana(
                                      fontSize: 14,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    curso['titulo'] ?? "Curso Premium",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Fecha de emisión:",
                                            style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey),
                                          ),
                                          Text(
                                            "${fecha.day}/${fecha.month}/${fecha.year}",
                                            style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          Text(
                                            "Kelvin Acevedo H.",
                                            style: GoogleFonts.dancingScript(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                          ),
                                          Container(height: 1, width: 100, color: Colors.grey[300]),
                                          Text(
                                            "Director Académico",
                                            style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: QrImageView(
                                          data: "https://silver-axolotl-4db970.netlify.app/?id=$hash",
                                          version: QrVersions.auto,
                                          size: 40,
                                          gapless: false,
                                          eyeStyle: const QrEyeStyle(
                                            eyeShape: QrEyeShape.square,
                                            color: Colors.black87,
                                          ),
                                          dataModuleStyle: const QrDataModuleStyle(
                                            dataModuleShape: QrDataModuleShape.square,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "ID DE VERIFICACIÓN",
              style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: hash));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡ID de verificación copiado al portapapeles! 📋'),
                    backgroundColor: Color(0xFF6366F1),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        hash,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sourceCodePro(color: const Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded, color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            ElevatedButton.icon(
              onPressed: () => _showQrModal(context, hash),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text("Ver mi QR"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981), // Color esmeralda para destacar
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _captureAndShareImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text("Descargar como Imagen"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final url = Uri.parse("https://www.linkedin.com/");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.work),
              label: const Text("Añadir a LinkedIn"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final Uri url;
                if (kIsWeb) {
                  url = Uri.parse("${Uri.base.scheme}://${Uri.base.host}:${Uri.base.port}/index.html");
                } else {
                  url = Uri.parse("file:///C:/Aura%20Academy/index.html");
                }
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.verified_user_rounded),
              label: const Text("Validar Certificado en la Web"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBorderDecoration() {
    return Stack(
      children: [
        Positioned(top: 0, left: 0, child: _buildCorner(0)),
        Positioned(top: 0, right: 0, child: _buildCorner(1)),
        Positioned(bottom: 0, left: 0, child: _buildCorner(2)),
        Positioned(bottom: 0, right: 0, child: _buildCorner(3)),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorner(int quarter) {
    return Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(10),
      child: RotatedBox(
        quarterTurns: quarter,
        child: CustomPaint(
          painter: CornerPainter(),
        ),
      ),
    );
  }
}

class CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}





