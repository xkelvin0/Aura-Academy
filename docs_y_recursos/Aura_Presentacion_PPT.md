# PRESENTACIÓN: AURA ACADEMY - LA EVOLUCIÓN DE LA EDTECH

---

## 🎬 DIAPOSITIVA 1: PORTADA
* **Título:** AURA ACADEMY
* **Subtítulo:** Aprendizaje Inteligente, Interactivo y Gamificado
* **Visual sugerido:** Captura de pantalla de la app en mockup móvil premium con el logo violeta brillante y avatares de estudiantes en el Dashboard.
* **Nota del orador:**
  > "Bienvenidos. Hoy les presento Aura Academy, no solo como una plataforma de cursos, sino como un ecosistema diseñado para resolver los dos problemas históricos del e-learning: la deserción y la falta de interactividad en video."

---

## 🛑 DIAPOSITIVA 2: EL PROBLEMA
* **Título:** La Epidemia del Aburrimiento Digital
* **Puntos clave:**
  * 📉 **Deserción del 90%:** La tasa promedio de finalización en cursos grabados tradicionales.
  * 🥱 **Videos pasivos:** El estudiante solo observa la pantalla sin interactuar.
  * ❓ **Dudas sin resolver:** Esperas de días o semanas en foros para que un instructor responda una consulta.
* **Visual sugerido:** Gráfico circular o de barras contrastando las tasas de abandono de la educación digital tradicional contra la presencial.

---

## 💡 DIAPOSITIVA 3: LA SOLUCIÓN
* **Título:** Aura Academy: El Futuro es Activo
* **Puntos clave:**
  * 🤖 **Aura AI 2.0:** Tutoría de Inteligencia Artificial contextualizada al segundo exacto del video que ves.
  * 🏆 **Gamificación Inmersiva:** Un sistema que convierte la constancia de estudio en un juego diario.
  * 💻 **Ecosistema Multiplataforma:** Sincronización en tiempo real entre Escritorio (Windows) y Móviles, dándole libertad total al estudiante para aprender sin barreras.
* **Visual sugerido:** Iconos premium con los 3 pilares conectados hacia el núcleo de Aura Academy.

---

## 🧠 DIAPOSITIVA 4: TUTORÍA CONTEXTUAL CON AURA AI 2.0
* **Título:** Aura AI: Tu Tutor Privado 24/7
* **Puntos clave:**
  * 🎯 **Entendimiento del Contexto:** Sabe qué curso y qué lección exacta está viendo el estudiante.
  * ⚡ **Respuestas Inmediatas:** Explica código, resume conceptos complejos y responde dudas en segundos sin salir del reproductor.
  * 🔒 **Seguro y Enfocado:** Restringido a asistencia puramente académica (sin desvíos de tema).
* **Visual sugerido:** Mockup del reproductor de video mostrando la burbuja flotante del tutor de IA desplegando una explicación técnica paso a paso.

---

## 🏆 DIAPOSITIVA 5: GAMIFICACIÓN AVANZADA
* **Título:** Convertir el Estudio en un Hábito Diario
* **Puntos clave:**
  * 🎯 **Aura Quests:** Misiones diarias y semanales dinámicas sincronizadas con Supabase (ej. "Estudia 15 min hoy").
  * 🔥 **Rachas e Impulso:** Motivación a través del fuego de días consecutivos activos.
  * 🏅 **Medallas y Logros:** Pop-ups con confeti al desbloquear hitos reales (Paso Inicial, Estudiante Nocturno).
* **Visual sugerido:** Captura de la pestaña "Misiones" y el diálogo premium animado de "¡Logro Desbloqueado!".

---

## 📊 DIAPOSITIVA 6: LEAGUE OF LEADERS (RANKINGS)
* **Título:** Competencia Sana y Clasificaciones
* **Puntos clave:**
  * 🌍 **Liga Global:** Ranking semanal de toda la academia ordenado por horas de estudio efectivas.
  * 🎓 **Liga por Curso:** Tabla de posiciones interna por curso basada en porcentaje de progreso completado.
  * ⏱️ **Sincronización en la Nube:** Impulsado por disparadores (triggers) en Supabase para evitar trampas.
* **Visual sugerido:** Captura de pantalla del podio de ganadores (1er, 2do y 3er puesto) con copas de oro, plata y bronce.

---

## 🏗️ DIAPOSITIVA 7: ESTRUCTURA DEL PROYECTO
* **Título:** Arquitectura y Organización del Código
* **Puntos clave:**
  * 📁 **`lib/screens/`:** Vistas modulares divididas por dominio (auth, courses, dashboard, instructor, profile).
  * 📁 **`lib/widgets/`:** Componentes UI reutilizables (AuraChatWidget, botones, tarjetas premium).
  * 📁 **`lib/services/`:** Lógica de negocio externa (GroqService para IA, SupabaseService).
  * 🗄️ **Base de Datos (Supabase):** Arquitectura relacional (Cursos, Módulos, Lecciones) optimizada con Triggers y RPCs en PostgreSQL.
* **Visual sugerido:** Un diagrama de árbol o carpetas mostrando cómo el Frontend (Flutter) se conecta ordenadamente con los servicios de Backend (Supabase) y el modelo de IA.

---

## 💻 DIAPOSITIVA 8: CÓDIGOS CLAVE DEL SISTEMA
* **Título:** El Motor Detrás de Aura Academy
* **Punto clave 1: Integración de IA Contextual (Flutter + Groq)**
  * Mostrar cómo la aplicación inyecta el contexto exacto del video al modelo de inteligencia artificial:
  ```dart
  // aura_chat_widget.dart - Prompt del Sistema
  final prompt = '''
  Eres Aura, un tutor asistente experto.
  El alumno está viendo el curso: "$courseTitle".
  Actualmente está en la lección: "$lessonTitle".
  Responde sus dudas basándote estrictamente en el contexto de esta clase.
  ''';
  final response = await GroqService.getChatCompletion(prompt, userMessage);
  ```
* **Punto clave 2: Automatización Backend (PostgreSQL Triggers)**
  * Mostrar cómo Supabase maneja la gamificación en la nube de forma segura sin depender del frontend:
  ```sql
  -- Función que otorga medallas y certificados automáticamente (Backend)
  CREATE OR REPLACE FUNCTION generar_certificado_automatico() RETURNS trigger AS $$
  BEGIN
      IF NEW.progreso_porcentaje = 100 THEN
          INSERT INTO certificados (perfil_id, curso_id, fecha_emision)
          VALUES (NEW.perfil_id, NEW.curso_id, NOW());
          
          -- Otorgar la medalla "Devorador de Cursos"
          INSERT INTO perfiles_medallas (perfil_id, medalla_id) 
          VALUES (NEW.perfil_id, (SELECT id FROM medallas WHERE requisito_tipo = 'PRIMER_DIPLOMA'));
      END IF;
      RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;
  ```
* **Visual sugerido:** Capturas de pantalla de los bloques de código (estilo modo oscuro tipo VS Code) acompañadas de íconos que representen "Cerebro/IA" y "Base de Datos/Nube".

---

## 💻 DIAPOSITIVA 9: CÓDIGOS CLAVE - MOTOR MULTIMEDIA Y CÁLCULOS
* **Título:** Lógica Avanzada de Reproducción y Gamificación
* **Punto clave 3: Reproductor Multiplataforma Inteligente (Flutter)**
  * Mostrar cómo la aplicación detecta la plataforma y adapta el reproductor de video (Windows vs Web/Móvil):
  ```dart
  // lesson_player_screen.dart - Adaptación Multiplataforma
  void _initializeVideoPlayer() {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      // Uso de motor nativo y optimizado para móviles/web
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          setState(() { _videoController!.play(); });
        });
    } else if (Platform.isWindows) {
      // Motor especializado (federated plugin) para escritorio Windows
      _videoPlayerWinController = WinVideoPlayerController.network(videoUrl)
        ..initialize().then((_) {
          setState(() { _videoPlayerWinController!.play(); });
        });
    }
  }
  ```
* **Punto clave 4: Algoritmo de Gamificación Dinámica**
  * Mostrar cómo la plataforma calcula inteligentemente las horas de estudio dividiendo la duración del curso entre las lecciones completadas:
  ```dart
  // leaderboard_screen.dart - Cálculo dinámico de horas reales de estudio
  final String duracionTexto = item['cursos']['duracion_texto'] ?? '10.0';
  // Extrae solo los números (ej. de "15 horas y media" extrae "15.0")
  final double cursoHoras = double.tryParse(duracionTexto.replaceAll(RegExp(r'[^0-9\.]'), '')) ?? 10.0;
  
  // Divide las horas totales entre la cantidad exacta de lecciones del curso
  final int totalLecciones = await _countLessonsForCourse(courseId);
  final double leccionHoras = (cursoHoras / totalLecciones).clamp(0.1, 10.0);
  
  todayHours += leccionHoras; // Suma precisa al Ranking Semanal
  ```
* **Visual sugerido:** Capturas de código elegante con iconos de un "Monitor/Móvil" para la lógica de video y un "Trofeo" para la lógica de matemáticas y gamificación.

---

## 🛠️ DIAPOSITIVA 10: TECNOLOGÍA Y ARQUITECTURA
* **Título:** Una Base Tecnológica de Alto Rendimiento
* **Puntos clave:**
  * 🏛️ **Arquitectura de Software:** Arquitectura Modular Orientada a Servicios. El código está estrictamente desacoplado separando las vistas (`screens`), los componentes de UI (`widgets`), los datos (`models`) y la lógica externa (`services`).
  * 📱 **Frontend:** Flutter (Dart) para experiencia nativa idéntica en Android, iOS y Windows Desktop.
  * ☁️ **Backend Serverless:** Supabase como base de datos (PostgreSQL), ejecutando la lógica pesada directamente en la nube mediante Triggers y RPCs (Arquitectura orientada a datos).
  * 🤖 **Cerebro IA:** Groq API conectada a modelos Llama de baja latencia.
* **Visual sugerido:** Diagrama de flujo mostrando la interacción entre Flutter, Supabase y Groq API.

---

## 🚀 DIAPOSITIVA 11: CONCLUSIÓN Y VISIÓN
* **Título:** Redefiniendo el E-Learning
* **Puntos clave:**
  * 📈 **Alta retención:** Alumnos enganchados por las ligas y rachas diarias.
  * 🧠 **Mejor aprendizaje:** Respuestas inmediatas gracias al Tutor de IA Contextual.
  * 💻 **Escalabilidad Global:** Estructura en la nube optimizada y lista para miles de alumnos.
* **Llamado a la acción:** "Aura Academy: Aprende a tu propio ritmo, compite con el mundo."
