-- PARCHE DEFINITIVO DE PERMISOS Y LIMPIEZA
ALTER TABLE public.cursos ENABLE ROW LEVEL SECURITY;

-- 1. Permiso de borrado
DROP POLICY IF EXISTS "Instructores pueden eliminar sus cursos" ON public.cursos;
CREATE POLICY "Instructores pueden eliminar sus cursos" ON public.cursos
FOR DELETE TO authenticated USING (instructor_id = auth.uid());

-- 2. Limpieza manual de "pedro"
DELETE FROM public.cursos WHERE titulo ILIKE '%pedro%';
