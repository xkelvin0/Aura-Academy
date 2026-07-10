import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseStudentsScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseStudentsScreen({
    super.key, 
    required this.courseId, 
    required this.courseTitle
  });

  @override
  State<CourseStudentsScreen> createState() => _CourseStudentsScreenState();
}

class _CourseStudentsScreenState extends State<CourseStudentsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final results = await supabase
          .from('inscripciones')
          .select('*, perfiles(*)')
          .eq('curso_id', widget.courseId)
          .neq('perfil_id', user.id) // <--- Excluir al instructor mismo
          .order('ultima_vez_visto', ascending: false);

      setState(() {
        _students = List<Map<String, dynamic>>.from(results);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando alumnos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatStudyTime(double decimalHours) {
    int totalMinutes = (decimalHours * 60).round();
    if (totalMinutes < 60) return "$totalMinutes min";
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    if (minutes == 0) return "${hours}h";
    return "${hours}h ${minutes}m";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Relación de Alumnos",
              style: GoogleFonts.montserrat(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.courseTitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF64748B)),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? _buildEmptyState()
              : _buildStudentList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline_rounded, size: 80, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text("Sin alumnos inscritos aún", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 8),
          const Text("Cuando alguien se inscriba,\naparecerá aquí su progreso.", textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _students.length,
      itemBuilder: (context, index) => _buildStudentCard(_students[index]),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> data) {
    final student = data['perfiles'];
    final progress = (data['progreso_porcentaje'] ?? 0).toDouble();
    final hours = double.tryParse(student['horas_estudio_total']?.toString() ?? "0.0") ?? 0.0;
    final racha = student['racha_dias'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE8E7FF),
                child: Text(student['nombre_completo'][0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student['nombre_completo'], style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("Última actividad: ${data['ultima_vez_visto'] != null ? 'Recientemente' : 'Sin datos'}", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ),
              if (racha > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orange, size: 12),
                      const SizedBox(width: 4),
                      Text(racha.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat("Progreso", "${progress.toInt()}%"),
              _buildMiniStat("Estudio Total", _formatStudyTime(hours)),
              _buildMiniStat("Meta Semanal", "${data['porcentaje_alcanzado'] ?? 0}%"),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: const Color(0xFFF1F5F9),
            color: const Color(0xFF6366F1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      ],
    );
  }
}





