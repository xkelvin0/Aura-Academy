-- REPARACIÓN DE PERMISOS PARA PERFILES
ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas antiguas si existen
DROP POLICY IF EXISTS "Usuarios pueden ver todos los perfiles" ON perfiles;
DROP POLICY IF EXISTS "Usuarios pueden insertar su propio perfil" ON perfiles;
DROP POLICY IF EXISTS "Usuarios pueden actualizar su propio perfil" ON perfiles;
DROP POLICY IF EXISTS "Permitir todo a usuarios autenticados" ON perfiles;

-- Crear una política global que permita al usuario hacer TODO con su propio registro
CREATE POLICY "Permitir todo sobre el propio perfil" 
ON perfiles 
FOR ALL 
TO authenticated 
USING (auth.uid() = id) 
WITH CHECK (auth.uid() = id);

-- Permitir que otros vean los perfiles (para ver quién es el instructor, etc)
CREATE POLICY "Perfiles son visibles para todos" 
ON perfiles 
FOR SELECT 
TO authenticated, anon 
USING (true);

-- Dar permisos de tabla a los roles de Supabase
GRANT ALL ON perfiles TO authenticated;
GRANT ALL ON perfiles TO anon;
GRANT ALL ON perfiles TO service_role;
