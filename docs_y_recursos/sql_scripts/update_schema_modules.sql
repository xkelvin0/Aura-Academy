-- 1. Crear tabla de modulos si no existe
CREATE TABLE IF NOT EXISTS public.modulos (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  curso_id uuid REFERENCES public.cursos(id) ON DELETE CASCADE,
  titulo text NOT NULL,
  orden int NOT NULL
);

-- 2. Vincular lecciones a modulos (opcionalmente)
ALTER TABLE public.lecciones ADD COLUMN IF NOT EXISTS modulo_id uuid REFERENCES public.modulos(id) ON DELETE CASCADE;

-- 3. Seguridad (RLS)
ALTER TABLE public.modulos ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Lectura pública de módulos') THEN
        CREATE POLICY "Lectura pública de módulos" ON public.modulos FOR SELECT TO public USING (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Instructores manejan sus módulos') THEN
        CREATE POLICY "Instructores manejan sus módulos" ON public.modulos FOR ALL TO authenticated 
        USING (EXISTS (SELECT 1 FROM public.cursos WHERE id = curso_id AND instructor_id = auth.uid()));
    END IF;
END $$;
