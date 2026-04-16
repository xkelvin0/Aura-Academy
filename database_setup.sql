-- SCRIPT DE BASE DE DATOS PARA AURA ACADEMY - ARQUITECTURA EDTECH PREMIUM
-- Copia y pega esto en el SQL Editor de Supabase y aprieta "RUN"

-- ==========================================
-- 0. LIMPIEZA DE COLISIONES (Drop Seguro)
-- ==========================================
-- Estas líneas eliminan las definiciones antiguas (y sus datos dummy) sin tocar tus Usuarios/Auth.
DROP TABLE IF EXISTS metas_semanales CASCADE;
DROP TABLE IF EXISTS inscripciones CASCADE;
DROP TABLE IF EXISTS lecciones CASCADE;
DROP TABLE IF EXISTS recursos_leccion CASCADE;
DROP TABLE IF EXISTS resenas CASCADE;
DROP TABLE IF EXISTS lista_deseos CASCADE;
DROP TABLE IF EXISTS certificados CASCADE;
DROP TABLE IF EXISTS transacciones CASCADE;
DROP TABLE IF EXISTS cursos CASCADE;
DROP TABLE IF EXISTS categorias CASCADE;
DROP TABLE IF EXISTS instructores CASCADE; -- ¡Esta es la que ya no usaremos!

-- ==========================================
-- 1. CATEGORÍAS
-- ==========================================
CREATE TABLE IF NOT EXISTS categorias (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre text NOT NULL,
  icono_nombre text, 
  color_hex text 
);

-- ==========================================
-- 2. CURSOS
-- ==========================================
CREATE TABLE IF NOT EXISTS cursos (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  titulo text NOT NULL, 
  subtitulo text, 
  descripcion text,
  categoria_id uuid REFERENCES categorias(id) ON DELETE SET NULL,
  instructor_id uuid REFERENCES perfiles(id) ON DELETE CASCADE, -- Ahora anidado al perfil del creador
  precio numeric(10, 2) DEFAULT 0.0, 
  rating_promedio numeric(3, 2) DEFAULT 0.0, -- Se calculará midiendo las reseñas reales
  thumbnail_url text, 
  duracion_texto text, 
  nivel text DEFAULT 'Principiante', 
  es_destacado boolean DEFAULT false,
  fecha_creacion timestamp with time zone DEFAULT now()
);

-- ==========================================
-- 3. LECCIONES Y RECURSOS DIDÁCTICOS
-- ==========================================
CREATE TABLE IF NOT EXISTS lecciones (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  curso_id uuid REFERENCES cursos(id) ON DELETE CASCADE,
  titulo text NOT NULL,
  descripcion text,
  video_url text, -- Link al streaming del video
  es_preview boolean DEFAULT false, -- Si es true, el usuario puede verlo sin comprar
  orden int NOT NULL
);

-- Archivos adjuntos para la clase (PDFs, ZIPs de código)
CREATE TABLE IF NOT EXISTS recursos_leccion (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  leccion_id uuid REFERENCES lecciones(id) ON DELETE CASCADE,
  nombre text NOT NULL,
  archivo_url text NOT NULL,
  tipo text -- 'PDF', 'ZIP', 'IMAGEN'
);

-- ==========================================
-- 4. ECONOMÍA FINTECH (ACCESOS Y TRANSACCIONES)
-- ==========================================
-- Guarda el rastro auditable financiero de las compras
CREATE TABLE IF NOT EXISTS transacciones (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id uuid REFERENCES perfiles(id) ON DELETE RESTRICT,
  curso_id uuid REFERENCES cursos(id) ON DELETE RESTRICT,
  monto numeric(10, 2) NOT NULL,
  metodo_pago text, -- Ej: 'Stripe', 'Google Pay', 'Apple Pay'
  estado text DEFAULT 'Completado',
  fecha timestamp with time zone DEFAULT now()
);

-- ==========================================
-- 5. INSCRIPCIONES Y PROGRESO (LMS)
-- ==========================================
CREATE TABLE IF NOT EXISTS inscripciones (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id uuid REFERENCES perfiles(id) ON DELETE CASCADE,
  curso_id uuid REFERENCES cursos(id) ON DELETE CASCADE,
  progreso_porcentaje int DEFAULT 0,
  lecciones_completadas int DEFAULT 0,
  ultima_leccion_id uuid REFERENCES lecciones(id) ON DELETE SET NULL,
  en_progreso boolean DEFAULT true,
  ultima_vez_visto timestamp with time zone DEFAULT now(),
  UNIQUE(perfil_id, curso_id) -- Seguro contra dobles cobros/suscripciones
);

-- ==========================================
-- 6. INTERACCIÓN SOCIAL Y FIDELIZACIÓN
-- ==========================================
-- Reseñas orgánicas del producto
CREATE TABLE IF NOT EXISTS resenas (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id uuid REFERENCES perfiles(id) ON DELETE CASCADE,
  curso_id uuid REFERENCES cursos(id) ON DELETE CASCADE,
  estrellas int CHECK (estrellas >= 1 AND estrellas <= 5) NOT NULL,
  comentario text,
  fecha timestamp with time zone DEFAULT now(),
  UNIQUE(perfil_id, curso_id) -- 1 voto por persona por curso
);

-- Guardar en Wishlist
CREATE TABLE IF NOT EXISTS lista_deseos (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id uuid REFERENCES perfiles(id) ON DELETE CASCADE,
  curso_id uuid REFERENCES cursos(id) ON DELETE CASCADE,
  fecha_agregado timestamp with time zone DEFAULT now(),
  UNIQUE(perfil_id, curso_id)
);

-- ==========================================
-- 7. ACREDITACIÓN AURA ACADEMY
-- ==========================================
CREATE TABLE IF NOT EXISTS certificados (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id uuid REFERENCES perfiles(id) ON DELETE CASCADE,
  curso_id uuid REFERENCES cursos(id) ON DELETE CASCADE,
  hash_validacion text UNIQUE NOT NULL, -- UUID de firma pública (valuable para portafolios Web)
  pdf_url text, -- Link al bucket del diploma generado
  fecha_emision timestamp with time zone DEFAULT now(),
  UNIQUE(perfil_id, curso_id)
);

-- ==========================================
-- 8. GAMIFICACIÓN
-- ==========================================
CREATE TABLE IF NOT EXISTS metas_semanales (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id uuid REFERENCES perfiles(id) ON DELETE CASCADE,
  horas_estudiadas numeric(5, 1) DEFAULT 0.0,
  porcentaje_alcanzado int DEFAULT 0,
  semana_inicio date DEFAULT CURRENT_DATE,
  UNIQUE(perfil_id, semana_inicio)
);
