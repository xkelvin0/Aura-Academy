import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart'; // <--- Importación necesaria

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _avatarController;
  late TextEditingController _phoneController;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _avatarController = TextEditingController();
    _phoneController = TextEditingController();
    _loadCurrentProfile();
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);

    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;

    setState(() => _isSaving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final bytes = result.files.first.bytes!;
      final fileExt = result.files.first.extension ?? 'png';
      final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      // Subir al bucket 'avatars'
      await supabase.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
      );

      // Obtener la URL pública
      final imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      
      setState(() {
        _avatarController.text = imageUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Foto de perfil actualizada! 📸✨"), backgroundColor: Color(0xFF0D9488)),
        );
      }
    } catch (e) {
      debugPrint("Error subiendo imagen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al subir la imagen."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('perfiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        
        if (data != null) {
          _nameController.text = data['nombre_completo'] ?? "";
          _bioController.text = data['biografia'] ?? "";
          _avatarController.text = data['avatar_url'] ?? "";
          _phoneController.text = data['celular'] ?? "";
        } else {
          // Si no hay perfil en BD, usamos metadata de Google
          _nameController.text = user.userMetadata?['full_name'] ?? "";
          _avatarController.text = user.userMetadata?['avatar_url'] ?? "";
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error cargando perfil para editar: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('perfiles').upsert({
          'id': user.id,
          'nombre_completo': _nameController.text.trim(),
          'email': user.email, // <--- CAMBIO CRÍTICO: Incluir email obligatorio
          'biografia': _bioController.text.trim(),
          'avatar_url': _avatarController.text.trim(),
          'celular': _phoneController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("¡Perfil actualizado con éxito! ✨"), backgroundColor: Color(0xFF0D9488)),
          );
          Navigator.pop(context, true); // Volver avisando que hubo cambios
        }
      }
    } catch (e) {
      debugPrint("Error guardando perfil: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al guardar los cambios."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _avatarController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "U";
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return "U";
    if (parts.length == 1) return parts[0][0].toUpperCase();
    if (parts.length >= 3) return "${parts[0][0]}${parts[2][0]}".toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _avatarController.text.isNotEmpty;
    final initials = _getInitials(_nameController.text);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Editar Perfil",
          style: GoogleFonts.montserrat(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("GUARDAR", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: const Color(0xFFF1F5F9),
                            backgroundImage: hasPhoto 
                                ? NetworkImage(_avatarController.text) 
                                : null,
                            child: !hasPhoto 
                                ? Text(
                                    initials,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isSaving ? null : _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                                child: _isSaving 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                          if (hasPhoto)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("¿Eliminar foto?"),
                                      content: const Text("¿Estás seguro de que quieres quitar tu foto de perfil actual?"),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("CANCELAR", style: TextStyle(color: Color(0xFF64748B))),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            setState(() => _avatarController.clear());
                                            Navigator.pop(context);
                                          },
                                          child: const Text("ELIMINAR", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildLabel("NOMBRE COMPLETO"),
                    _buildTextField(_nameController, "Tu nombre artístico o real", Icons.person_outline, isRequired: true),
                    const SizedBox(height: 24),
                    _buildLabel("BIOGRAFÍA"),
                    _buildTextField(_bioController, "Cuéntanos sobre ti...", Icons.edit_note_rounded, maxLines: 4),
                    const SizedBox(height: 24),
                    _buildLabel("CELULAR"),
                    _buildTextField(_phoneController, "+51 987 654 321", Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                    const SizedBox(height: 24),
                    _buildLabel("URL DE AVATAR (URL)"),
                    _buildTextField(_avatarController, "Enlace a tu imagen de perfil", Icons.link_rounded),
                    const SizedBox(height: 32),
                    const Text(
                      "La información de tu perfil es pública para instructores y otros alumnos en Aura Academy.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 1),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String hint, 
    IconData icon, {
    int maxLines = 1, 
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: isRequired 
            ? (value) => value == null || value.isEmpty ? "Este campo es obligatorio" : null
            : null,
      ),
    );
  }
}






