-- Eliminar la política restrictiva
DROP POLICY IF EXISTS "Un usuario puede ver su propio perfil" ON public.perfiles;

-- Crear una política que permita a todos ver los perfiles (necesario para ver quién es el instructor)
CREATE POLICY "Lectura pública de perfiles" 
ON public.perfiles 
FOR SELECT 
TO public 
USING (true);
