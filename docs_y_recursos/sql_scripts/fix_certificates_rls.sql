-- POLÍTICAS PARA CERTIFICADOS
ALTER TABLE certificados ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuarios pueden ver sus propios certificados" ON certificados;
CREATE POLICY "Usuarios pueden ver sus propios certificados" 
ON certificados FOR SELECT 
TO authenticated 
USING (auth.uid() = perfil_id);

-- El trigger de inserción usa SECURITY DEFINER, por lo que no necesita política de INSERT para el usuario,
-- pero por si acaso y para debug:
DROP POLICY IF EXISTS "Sistema puede insertar certificados" ON certificados;
CREATE POLICY "Sistema puede insertar certificados" 
ON certificados FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = perfil_id);
