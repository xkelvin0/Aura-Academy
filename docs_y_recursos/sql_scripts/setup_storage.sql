-- 1. Crear el bucket si no existe
INSERT INTO storage.buckets (id, name, public) 
VALUES ('miniaturas', 'miniaturas', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Política para que cualquiera pueda ver las imágenes (Público)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage' 
        AND policyname = 'Acceso público para ver miniaturas'
    ) THEN
        CREATE POLICY "Acceso público para ver miniaturas" ON storage.objects
        FOR SELECT TO public USING (bucket_id = 'miniaturas');
    END IF;
END $$;

-- 3. Política para que instructores autenticados puedan subir imágenes
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage' 
        AND policyname = 'Instructores pueden subir miniaturas'
    ) THEN
        CREATE POLICY "Instructores pueden subir miniaturas" ON storage.objects
        FOR INSERT TO authenticated WITH CHECK (bucket_id = 'miniaturas');
    END IF;
END $$;
