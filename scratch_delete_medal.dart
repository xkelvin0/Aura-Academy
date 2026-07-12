import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'lib/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  
  final supabase = Supabase.instance.client;
  
  // Obtener id de la medalla ESTUDIO_NOCTURNO
  final medallaRes = await supabase.from('medallas').select('id').eq('requisito_tipo', 'ESTUDIO_NOCTURNO').maybeSingle();
  if (medallaRes != null) {
    print('Borrando medalla ESTUDIO_NOCTURNO de todos los perfiles para resetear...');
    await supabase.from('perfiles_medallas').delete().eq('medalla_id', medallaRes['id']);
    print('Reset completado.');
  } else {
    print('Medalla no encontrada');
  }
}
