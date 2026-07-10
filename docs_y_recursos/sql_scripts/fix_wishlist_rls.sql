-- POLÍTICAS PARA LISTA DE DESEOS
ALTER TABLE lista_deseos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuarios pueden ver su lista de deseos" ON lista_deseos;
CREATE POLICY "Usuarios pueden ver su lista de deseos" ON lista_deseos 
FOR SELECT USING (auth.uid() = perfil_id);

DROP POLICY IF EXISTS "Usuarios pueden agregar a su lista de deseos" ON lista_deseos;
CREATE POLICY "Usuarios pueden agregar a su lista de deseos" ON lista_deseos 
FOR INSERT WITH CHECK (auth.uid() = perfil_id);

DROP POLICY IF EXISTS "Usuarios pueden quitar de su lista de deseos" ON lista_deseos;
CREATE POLICY "Usuarios pueden quitar de su lista de deseos" ON lista_deseos 
FOR DELETE USING (auth.uid() = perfil_id);
