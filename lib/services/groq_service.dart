import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aura_academy/secrets.dart';

class GroqMessage {
  final String role;
  final String content;
  GroqMessage({required this.role, required this.content});
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// Representa una accion que el bot quiere ejecutar en la app
class AppAction {
  final String type;     // navigate_tab, search_courses, open_certificates, open_settings
  final String? param;   // 0=home,1=search,2=courses,3=profile / query de busqueda

  AppAction({required this.type, this.param});
}

class GroqResponse {
  final String text;
  final AppAction? action;
  GroqResponse({required this.text, this.action});
}

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  static const String _systemPrompt = '''
Eres "Aura AI", el asistente inteligente oficial de Aura Academy, una plataforma de cursos online.
Tienes dos roles:
1. Tutor academico: explicas conceptos de programacion, diseno, tecnologia y otras materias.
2. Asistente de la app: puedes navegar por la app y ejecutar acciones por el usuario.

ACCIONES DISPONIBLES EN LA APP:
- Ir al inicio: escribe [ACTION:navigate_tab:0] en tu respuesta
- Ir a buscar/explorar cursos: escribe [ACTION:navigate_tab:1]
- Ir a mis cursos: escribe [ACTION:navigate_tab:2]
- Ir a mi perfil: escribe [ACTION:navigate_tab:3]
- Buscar un curso especifico: escribe [ACTION:search_courses:termino_de_busqueda]
- Abrir mis certificados: escribe [ACTION:open_certificates]
- Abrir configuracion: escribe [ACTION:open_settings]

CUANDO USAR ACCIONES:
- Únicamente incluye una acción si el usuario solicita explícitamente navegar, ir, buscar o abrir una pantalla.
- NO incluyas ninguna acción para saludos genéricos (como "hola", "buenas"), agradecimientos, charla informal o preguntas teóricas/académicas generales.
- Solo incluye UNA accion por respuesta.
- Pon la accion al FINAL del texto, en su propia linea.


Reglas generales:
- Responde SIEMPRE en espanol.
- Se conciso, amable y motivador.
- Usa emojis con moderacion.
- Maximo 200 palabras por respuesta.
''';

  final List<GroqMessage> _history = [];

  GroqService() {
    _history.add(GroqMessage(role: 'system', content: _systemPrompt));
  }

  Future<GroqResponse> sendMessage(String userMessage) async {
    _history.add(GroqMessage(role: 'user', content: userMessage));

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSecrets.groqApiKey}',
        },
        body: jsonEncode({
          'model': _model,
          'messages': _history.map((m) => m.toJson()).toList(),
          'temperature': 0.7,
          'max_tokens': 512,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final raw = data['choices'][0]['message']['content'] as String;

        // Extraer accion del texto si existe
        final actionRegex = RegExp(r'\[ACTION:([^:\]]+)(?::([^\]]+))?\]');
        final match = actionRegex.firstMatch(raw);

        AppAction? action;
        String cleanText = raw;

        if (match != null) {
          action = AppAction(type: match.group(1)!, param: match.group(2));
          cleanText = raw.replaceAll(actionRegex, '').trim();
        }

        _history.add(GroqMessage(role: 'assistant', content: cleanText));
        return GroqResponse(text: cleanText, action: action);
      } else {
        return GroqResponse(text: 'Error ${response.statusCode}: No pude conectarme. Intentalo de nuevo.');
      }
    } catch (e) {
      return GroqResponse(text: 'Error de conexion. Asegurate de tener internet.');
    }
  }

  void clearHistory() {
    _history.clear();
    _history.add(GroqMessage(role: 'system', content: _systemPrompt));
  }
}
