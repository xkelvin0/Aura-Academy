-- HABILITAR RLS Y POLÍTICAS PARA LECCIONES COMPLETADAS
ALTER TABLE lecciones_completadas ENABLE ROW LEVEL SECURITY;

-- Política para ver sus propias lecciones completadas
DROP POLICY IF EXISTS "Usuarios pueden ver sus propias lecciones completadas" ON lecciones_completadas;
CREATE POLICY "Usuarios pueden ver sus propias lecciones completadas" 
ON lecciones_completadas FOR SELECT 
TO authenticated 
USING (auth.uid() = perfil_id);

-- Política para insertar sus propias lecciones completadas
DROP POLICY IF EXISTS "Usuarios pueden marcar lecciones como completadas" ON lecciones_completadas;
CREATE POLICY "Usuarios pueden marcar lecciones como completadas" 
ON lecciones_completadas FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = perfil_id);

-- Política para eliminar (desmarcar) sus propias lecciones completadas
DROP POLICY IF EXISTS "Usuarios pueden desmarcar lecciones" ON lecciones_completadas;
CREATE POLICY "Usuarios pueden desmarcar lecciones" 
ON lecciones_completadas FOR DELETE 
TO authenticated 
USING (auth.uid() = perfil_id);

-- Asegurar que las inscripciones se puedan actualizar (el trigger corre con permisos del usuario usualmente)
ALTER TABLE inscripciones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Usuarios pueden actualizar su propio progreso" ON inscripciones;
CREATE POLICY "Usuarios pueden actualizar su propio progreso" 
ON inscripciones FOR UPDATE 
TO authenticated 
USING (auth.uid() = perfil_id);
