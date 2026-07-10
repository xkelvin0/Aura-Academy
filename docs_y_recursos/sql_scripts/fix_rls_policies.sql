-- Habilitar RLS en tablas principales
ALTER TABLE public.cursos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lecciones ENABLE ROW LEVEL SECURITY;

-- POLÍTICAS PARA CURSOS
-- 1. Lectura pública (Todos pueden ver los cursos)
DROP POLICY IF EXISTS "Lectura pública de cursos" ON public.cursos;
CREATE POLICY "Lectura pública de cursos" ON public.cursos
FOR SELECT TO public USING (true);

-- 2. Inserción (Instructores autenticados pueden crear si el ID coincide)
DROP POLICY IF EXISTS "Instructores pueden crear cursos" ON public.cursos;
CREATE POLICY "Instructores pueden crear cursos" ON public.cursos
FOR INSERT TO authenticated WITH CHECK (instructor_id = auth.uid());

-- 3. Actualización (Solo el dueño puede editar)
DROP POLICY IF EXISTS "Instructores pueden editar sus cursos" ON public.cursos;
CREATE POLICY "Instructores pueden editar sus cursos" ON public.cursos
FOR UPDATE TO authenticated USING (instructor_id = auth.uid());

-- POLÍTICAS PARA LECCIONES
-- 1. Lectura pública
DROP POLICY IF EXISTS "Lectura pública de lecciones" ON public.lecciones;
CREATE POLICY "Lectura pública de lecciones" ON public.lecciones
FOR SELECT TO public USING (true);

-- 2. Control total para el dueño del curso
DROP POLICY IF EXISTS "Instructores manejan lecciones" ON public.lecciones;
CREATE POLICY "Instructores manejan lecciones" ON public.lecciones
FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.cursos 
    WHERE id = curso_id AND instructor_id = auth.uid()
  )
);
