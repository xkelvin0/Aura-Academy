-- CONFIGURACIÓN DE STORAGE PARA AVATARS
-- 1. Crear el bucket 'avatars'
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Limpiar políticas antiguas
DROP POLICY IF EXISTS "Avatars públicos" ON storage.objects;
DROP POLICY IF EXISTS "Subida de avatars" ON storage.objects;
DROP POLICY IF EXISTS "Actualización de avatars" ON storage.objects;

-- 3. Crear políticas de acceso
-- Lectura pública
CREATE POLICY "Avatars públicos" 
ON storage.objects FOR SELECT 
TO public 
USING (bucket_id = 'avatars');

-- Subida (Insert) para usuarios autenticados
CREATE POLICY "Subida de avatars" 
ON storage.objects FOR INSERT 
TO authenticated 
WITH CHECK (bucket_id = 'avatars');

-- Actualización (Update) para usuarios autenticados
CREATE POLICY "Actualización de avatars" 
ON storage.objects FOR UPDATE 
TO authenticated 
WITH CHECK (bucket_id = 'avatars');
