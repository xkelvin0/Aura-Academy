# 📖 Manual de Funciones - Aura Academy

Aura Academy es ahora una plataforma de e-learning robusta con capacidades tanto para estudiantes como para instructores. Aquí tienes una guía detallada de todo lo que puedes hacer:

---

## 👨‍🏫 Para el Instructor (Creador de Contenido)

### 1. Panel de Instructor
* **Gestión de Cursos**: Visualiza todos tus cursos (Borradores y Publicados) en una lista organizada.
* **Indicadores Rápidos**: Mira el número de estudiantes, la valoración y el estado de cada curso.
* **Vista Previa Directa**: Un botón de "ojo" que te permite ver el curso exactamente como lo verá el alumno.

### 2. Creación y Edición de Cursos
* **Editor Multimedia**: Sube imágenes de portada personalizadas directamente desde tu galería.
* **Categorización**: Elige la disciplina correcta (Desarrollo, IA, Diseño, etc.) para que tu curso sea fácil de encontrar.
* **Sistema de Ofertas [NUEVO]**: 
    * Activa el interruptor de oferta.
    * Define un "Precio Original" para mostrar el descuento (precio tachado).
    * El sistema mostrará automáticamente el badge de **OFERTA** en el dashboard.

### 3. Estructura del Curso
* **Módulos y Lecciones**: Crea una jerarquía clara. Un curso se divide en Módulos, y cada módulo contiene múltiples Lecciones.
* **Guardado Automático**: Los cambios en la estructura se sincronizan con la base de datos mientras trabajas.

---

## 🎓 Para el Estudiante (Usuario)

### 1. Dashboard de Exploración
* **Filtrado Dinámico**: Toca una categoría (ej: "Desarrollo") para filtrar instantáneamente los cursos disponibles.
* **Pull-to-Refresh**: Desliza hacia abajo para actualizar los precios y ofertas más recientes.
* **Buscador**: Encuentra cursos específicos por nombre (Barra de búsqueda superior).

### 2. Detalle del Curso
* **Exploración de Temario**: Antes de comprar, puedes ver todos los módulos y lecciones que incluye el curso.
* **Badges de Oferta**: Identifica rápidamente los cursos con descuento gracias a las etiquetas resaltadas.
* **Transparencia de Precios**: Visualiza cuánto estás ahorrando con el formato de precio tachado.

### 3. Modo Continuar Aprendiendo
* El dashboard te recuerda tu último avance para que puedas retomar tus clases con un solo toque.

---

## 🛠️ Funciones del Sistema
* **Modo Instructor Automático**: Si eres el creador de un curso, el botón de "Comprar" se convierte en "Gestionar Curso", y todas las lecciones se desbloquean automáticamente para ti.
* **Autenticación Segura**: Sistema de registro e inicio de sesión conectado con Supabase Auth.
* **Almacenamiento en la Nube**: Todas las imágenes se suben a Supabase Storage de forma eficiente.
