-- LIBERAR PERMISOS PARA LECCIONES COMPLETADAS

-- 1. Habilitar RLS
ALTER TABLE lecciones_completadas ENABLE ROW LEVEL SECURITY;

-- 2. Borrar política vieja si existe
DROP POLICY IF EXISTS "Usuarios pueden manejar su propio progreso" ON lecciones_completadas;

-- 3. Crear política nueva (Permite INSERT, SELECT y DELETE para el dueño del perfil)
CREATE POLICY "Usuarios pueden manejar su propio progreso" 
ON lecciones_completadas 
FOR ALL 
TO authenticated 
USING (auth.uid() = perfil_id)
WITH CHECK (auth.uid() = perfil_id);

-- 4. Permisos de GRANT (por si acaso)
GRANT ALL ON lecciones_completadas TO authenticated;
GRANT ALL ON lecciones_completadas TO service_role;
