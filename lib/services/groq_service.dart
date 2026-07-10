import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aura_academy/secrets.dart';

class GroqMessage {
  final String role; // 'user' | 'assistant' | 'system'
  final String content;

  GroqMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  static const String _systemPrompt = '''
Eres "Aura AI", el asistente inteligente oficial de Aura Academy.
Tienes dos roles:
1. **Tutor académico**: Explicas conceptos de programación, diseño, tecnología y otras materias de los cursos de forma clara y didáctica.
2. **Asistente de plataforma**: Orientas a los usuarios sobre cómo usar Aura Academy (inscribirse a cursos, ver certificados, calificar cursos, etc.).

Reglas:
- Responde SIEMPRE en español.
- Sé conciso, amable y motivador.
- Si no sabes algo, admítelo honestamente.
- Usa emojis con moderación para hacer la experiencia más amigable.
- Cuando expliques código, usa bloques de código marcados.
- Máximo 300 palabras por respuesta salvo que el usuario pida una explicación larga.
''';

  final List<GroqMessage> _history = [];

  GroqService() {
    _history.add(GroqMessage(role: 'system', content: _systemPrompt));
  }

  Future<String> sendMessage(String userMessage) async {
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
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final assistantMessage = data['choices'][0]['message']['content'] as String;
        _history.add(GroqMessage(role: 'assistant', content: assistantMessage));
        return assistantMessage;
      } else {
        return 'Error ${response.statusCode}: No pude conectarme al servidor. Inténtalo de nuevo.';
      }
    } catch (e) {
      return 'Error de conexión: Asegúrate de tener internet e inténtalo de nuevo.';
    }
  }

  void clearHistory() {
    _history.clear();
    _history.add(GroqMessage(role: 'system', content: _systemPrompt));
  }
}
