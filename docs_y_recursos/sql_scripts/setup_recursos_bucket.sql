-- CONFIGURACIÓN DE BUCKET DE RECURSOS (PDF, ZIP, ETC)

-- 1. Crear el bucket si no existe
INSERT INTO storage.buckets (id, name, public) 
VALUES ('recursos', 'recursos', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Política para que cualquiera pueda ver/descargar los recursos
DROP POLICY IF EXISTS "Acceso público para ver recursos" ON storage.objects;
CREATE POLICY "Acceso público para ver recursos" ON storage.objects
FOR SELECT TO public USING (bucket_id = 'recursos');

-- 3. Política para que instructores autenticados puedan subir recursos
DROP POLICY IF EXISTS "Instructores pueden subir recursos" ON storage.objects;
CREATE POLICY "Instructores pueden subir recursos" ON storage.objects
FOR INSERT TO authenticated WITH CHECK (bucket_id = 'recursos');
