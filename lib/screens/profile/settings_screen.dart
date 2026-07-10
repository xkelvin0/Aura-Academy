import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_academy/main.dart'; // <--- Importación necesaria para el tema
import 'package:aura_academy/screens/profile/edit_profile_screen.dart';
import 'package:aura_academy/screens/auth/security_screen.dart'; // <--- Importación necesaria

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;
  bool _notificationsEnabled = true;
  // Ya no necesitamos _darkMode local, usamos el global

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Configuración",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionTitle("CUENTA"),
          _buildSettingsTile(
            icon: Icons.person_outline_rounded,
            title: "Editar Perfil",
            subtitle: "Nombre, biografía y foto",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.lock_outline_rounded,
            title: "Seguridad",
            subtitle: "Contraseña y autenticación",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecurityScreen()),
              );
            },
          ),
          const SizedBox(height: 32),
          _buildSectionTitle("PREFERENCIAS"),
          _buildSwitchTile(
            icon: Icons.notifications_none_rounded,
            title: "Notificaciones",
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
          _buildSwitchTile(
            icon: Icons.dark_mode_outlined,
            title: "Modo Oscuro",
            value: themeNotifier.value == ThemeMode.dark,
            onChanged: (val) {
              setState(() {
                themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              });
            },
          ),
          const SizedBox(height: 32),
          _buildSectionTitle("AURA ACADEMY"),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            title: "Sobre la App",
            subtitle: "Versión 1.0.0 + Aura Premium",
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.help_outline_rounded,
            title: "Ayuda y Soporte",
            onTap: () {},
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              "Aura Academy © 2026",
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF6366F1),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF475569), size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF475569), size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        activeColor: const Color(0xFF6366F1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}





