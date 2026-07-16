# 🛡️ CHEAT SHEET: DEFENSA DEL PROYECTO (PREGUNTAS DEL PROFESOR)

Si tu profesor es muy preguntón, intentará buscar los puntos débiles de tu arquitectura. Estudia esta guía; contiene las respuestas técnicas exactas basadas en el código real de Aura Academy.

---

### 1. ❓ "Veo que usan Supabase. ¿Por qué no usaron Firebase que es más común?"
**✅ Tu respuesta:**
> "Elegimos Supabase porque está construido sobre **PostgreSQL**, una base de datos relacional. Aura Academy tiene entidades muy conectadas: *Cursos* tienen *Módulos*, los módulos tienen *Lecciones*, y los perfiles tienen *Inscripciones* y *Logros*. Si usábamos Firebase (que es NoSQL), mantener la integridad referencial iba a ser una pesadilla y tendríamos datos duplicados. Además, Supabase nos permitió programar la lógica pesada (como entregar medallas) directo en el servidor usando **Triggers (Disparadores) SQL**, cosa que en Firebase requiere configurar Cloud Functions más lentas y costosas."

---

### 2. ❓ "¿Cómo se aseguran de que el usuario no pueda hackear la app para darse más puntos o XP?"
**✅ Tu respuesta:**
> "Aplicamos el principio de **Zero-Trust (Cero Confianza)** en el Frontend. La aplicación de celular (Flutter) no tiene permisos para sumarse XP a sí misma directamente. Lo que hace la app es simplemente decirle a la base de datos: *'Terminé esta lección'*. Toda la matemática y la validación ocurre en el Backend. Tenemos un *Trigger* en PostgreSQL que escucha cuándo se termina una lección, y es el propio servidor el que inyecta el XP al usuario. Si alguien hackea el APK, no podrá falsificar sus puntos porque la base de datos lo rechazaría mediante las políticas de seguridad **RLS (Row Level Security)**."

---

### 3. ❓ "¿Cómo funciona realmente el Tutor de IA? ¿No están simplemente incrustando ChatGPT y ya?"
**✅ Tu respuesta:**
> "No, no es un chat genérico. Nosotros desarrollamos un sistema de **Inyección de Contexto Dinámico (Prompt Engineering)**. En el archivo `aura_chat_widget.dart`, antes de enviar el mensaje del usuario a la API de **Groq** (usando el modelo Llama de baja latencia), nuestro código intercepta la petición y le incrusta ocultamente variables como el `$courseTitle` y `$lessonTitle`. Así, la IA asume el rol estricto de un tutor de ESA clase en específico. Si el alumno pregunta algo fuera de tema, la IA está programada para regresarlo al contexto académico."

---

### 4. ❓ "¿Por qué escogieron Flutter y cómo manejan la arquitectura del código?"
**✅ Tu respuesta:**
> "Flutter nos permitió compilar para Android, iOS y Escritorio (Windows) usando **un solo código fuente (Dart)**, ahorrando meses de desarrollo. Nuestra arquitectura está basada en características modulares (Feature-Driven). Separamos estrictamente la lógica: 
> * `screens/`: Solo tienen la Interfaz de Usuario (UI).
> * `widgets/`: Componentes reutilizables (botones, tarjetas).
> * `services/`: La lógica pesada de llamadas a APIs (SupabaseService, GroqService).
> No mezclamos lógica de negocio con la vista."

---

### 5. ❓ "He visto que tienen un reproductor de video en PC y otro en Android. ¿Por qué?"
**✅ Tu respuesta:**
> "Porque el renderizado nativo es diferente. Si usábamos un paquete genérico, el video iba a tener lag en Windows o iba a consumir mucha RAM. Para solucionarlo, en `lesson_player_screen.dart` implementamos un condicional de plataforma (`Platform.isWindows`). Si detectamos que es una PC, llamamos al motor `WinVideoPlayerController` escrito en C++ para Windows. Si es un móvil, usamos el motor nativo de ExoPlayer/AVPlayer. **Cero pérdida de rendimiento.**"

---

### 6. ❓ "¿Cómo hicieron la tabla de posiciones (League of Leaders)? ¿No se vuelve muy lenta si hay 1,000 alumnos?"
**✅ Tu respuesta:**
> "Para evitar problemas de rendimiento (Cuellos de botella), no descargamos toda la base de datos al teléfono. Hacemos las consultas matemáticas del lado del servidor. En `leaderboard_screen.dart` traemos la lista ya ordenada y limitada desde la nube usando `.order('horas_estudio', ascending: false).limit(10)`. Además, las horas se calculan dinámicamente dividiendo la duración oficial del curso entre la cantidad de lecciones. Es un algoritmo sumamente optimizado."

---

### 7. ❓ "¿Dónde guardan las contraseñas de los usuarios?"
**✅ Tu respuesta:**
> "Nosotros como desarrolladores **jamás vemos las contraseñas**. Usamos `Supabase Auth`, que implementa protocolos criptográficos (Bcrypt). Cuando un usuario se registra, el sistema nos devuelve un **Token JWT (JSON Web Token)**. Ese token se guarda de forma segura en el almacenamiento local encriptado del teléfono (`SharedPreferences`). Toda la comunicación se hace por el protocolo seguro HTTPS."
