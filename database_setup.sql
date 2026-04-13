-- SCRIPT DE BASE DE DATOS PARA AURA ACADEMY - HOME DESIGN
-- Copia y pega esto en el SQL Editor de Supabase

-- 1. Categorías (Sección: Principales Disciplinas)
CREATE TABLE IF NOT EXISTS categorias (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre text NOT NULL,
  icono_nombre text, -- Nombre del icono de FontAwesome (ej: 'code', 'pen-nib')
  color_hex text -- Color de fondo para el icono en la UI
);

-- 2. Instructores (Mentores - Sección: Colecciones Destacadas)
CREATE TABLE IF NOT EXISTS instructores (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre text NOT NULL, -- Ej: 'Sarah Jenkins'
  avatar_url text, -- Foto del instructor
  bio text
);

-- 3. Cursos (Catálogo Principal)
CREATE TABLE IF NOT EXISTS cursos (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  titulo text NOT NULL, -- Ej: 'Masterclass de Identidad Visual'
  subtitulo text, -- Ej: 'Domina el arte de los entornos...'
  categoria_id uuid REFERENCES categorias(id),
  instructor_id uuid REFERENCES instructores(id),
  precio numeric(10, 2) DEFAULT 0.0, -- Ej: 89.00
  rating numeric(2, 1) DEFAULT 0.0, -- Ej: 4.9
  thumbnail_url text, -- Imagen del curso
  duracion_texto text, -- Ej: "24h de contenido"
  nivel text DEFAULT 'Principiante', 
  es_destacado boolean DEFAULT false
);

-- 4. Lecciones (Para saber el total, ej: "/ 18 Lecciones")
CREATE TABLE IF NOT EXISTS lecciones (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  curso_id uuid REFERENCES cursos(id) ON DELETE CASCADE,
  titulo text NOT NULL,
  orden int NOT NULL
);

-- 5. Inscripciones y Progreso (Sección: Continuar Aprendiendo)
CREATE TABLE IF NOT EXISTS inscripciones (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id uuid REFERENCES perfiles(id) ON DELETE CASCADE,
  curso_id uuid REFERENCES cursos(id) ON DELETE CASCADE,
  progreso_porcentaje int DEFAULT 0, -- Ej: 65 (para la barra de progreso)
  lecciones_completadas int DEFAULT 0, -- Ej: 12
  ultima_leccion_id uuid REFERENCES lecciones(id),
  en_progreso boolean DEFAULT true,
  ultima_vez_visto timestamp with time zone DEFAULT now(),
  UNIQUE(perfil_id, curso_id)
);

-- 6. Metas Semanales (Sección: Meta Semanal)
CREATE TABLE IF NOT EXISTS metas_semanales (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id uuid REFERENCES perfiles(id) ON DELETE CASCADE,
  horas_estudiadas numeric(5, 1) DEFAULT 0.0, -- Ej: 4.5
  porcentaje_alcanzado int DEFAULT 0, -- Ej: 80
  semana_inicio date DEFAULT CURRENT_DATE,
  UNIQUE(perfil_id, semana_inicio)
);

-- --- DATOS DE PRUEBA (Opcional, para que veas el diseño con algo de info) ---

-- Insertar Categorías
INSERT INTO categorias (nombre, icono_nombre, color_hex) VALUES 
('Desarrollo', 'code', 'F1F5F9'),
('Diseño', 'pen-nib', 'F1F5F9'),
('Negocios', 'briefcase', 'F1F5F9'),
('Marketing', 'chart-bar', 'F1F5F9');

-- Insertar un Instructor
INSERT INTO instructores (nombre, bio) VALUES ('Sarah Jenkins', 'Expert designer with 10 years of experience.');

-- Insertar un Curso Destacado
INSERT INTO cursos (titulo, subtitulo, precio, rating, duracion_texto, es_destacado) 
VALUES ('Masterclass de Identidad Visual', 'Todo lo que necesitas para crear marcas impactantes.', 89.00, 4.9, '24h de contenido', true);
