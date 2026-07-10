-- Habilitar RLS en inscripciones (si no lo está)
ALTER TABLE public.inscripciones ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas antiguas para evitar conflictos
DROP POLICY IF EXISTS "Usuarios pueden ver sus propias inscripciones" ON public.inscripciones;
DROP POLICY IF EXISTS "Usuarios pueden inscribirse" ON public.inscripciones;

-- Política para que el usuario VEA sus propias compras
CREATE POLICY "Usuarios pueden ver sus propias inscripciones"
ON public.inscripciones
FOR SELECT
TO authenticated
USING (auth.uid() = perfil_id);

-- Política para que el usuario se INSCRIBA
CREATE POLICY "Usuarios pueden inscribirse"
ON public.inscripciones
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = perfil_id);

-- Política para que el INSTRUCTOR vea quién se inscribió en su curso
CREATE POLICY "Instructores pueden ver inscritos en sus cursos"
ON public.inscripciones
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.cursos
    WHERE cursos.id = inscripciones.curso_id
    AND cursos.instructor_id = auth.uid()
  )
);
