import 'package:supabase/supabase.dart';

Future<void> main() async {
  final supabase = SupabaseClient(
    'https://jfbwkofperbqvvvexvsc.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpmYndrb2ZwZXJicXZ2dmV4dnNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3OTk4MDAsImV4cCI6MjA5MTM3NTgwMH0.HXztt2dTbpItfdItaieqQrfZTPp7ft6kygU0hp4R7VU'
  );

  try {
    print("Verificando inserción con correo...");
    await supabase.from('perfiles').insert({
      'id': '11111111-1111-1111-1111-111111111111',
      'nombre_completo': 'Test Name 2',
      'email': 'testing2@gmail.com',
    });
    print("¡Exitoso!");
  } catch (e) {
    print("Error exacto devuelto por PostgreSQL: $e");
  }
}
