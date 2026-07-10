-- SISTEMA DE VISTAS ÚNICAS PRO

-- 1. Crear tabla para rastrear vistas individuales
CREATE TABLE IF NOT EXISTS vistas_unicas_cursos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    perfil_id UUID REFERENCES perfiles(id) ON DELETE CASCADE,
    curso_id UUID REFERENCES cursos(id) ON DELETE CASCADE,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Índice para que las búsquedas sean ultra rápidas
CREATE INDEX IF NOT EXISTS idx_vistas_unicas_perfil_curso ON vistas_unicas_cursos(perfil_id, curso_id);

-- 3. Actualizar la Llave Maestra (RPC) para manejar la lógica única
CREATE OR REPLACE FUNCTION incrementar_vistas_curso(id_curso UUID, id_usuario UUID)
RETURNS VOID AS $$
DECLARE
    v_ya_visto BOOLEAN;
BEGIN
    -- Verificar si el usuario ya vio este curso en las últimas 24 horas
    SELECT EXISTS (
        SELECT 1 FROM vistas_unicas_cursos 
        WHERE perfil_id = id_usuario 
        AND curso_id = id_curso 
        AND fecha > (NOW() - INTERVAL '24 hours')
    ) INTO v_ya_visto;

    -- Si NO lo ha visto en las últimas 24 horas, sumamos la vista y registramos
    IF NOT v_ya_visto THEN
        -- Registrar la vista
        INSERT INTO vistas_unicas_cursos (perfil_id, curso_id)
        VALUES (id_usuario, id_curso);

        -- Actualizar el contador global en la tabla cursos
        UPDATE cursos 
        SET vistas = COALESCE(vistas, 0) + 1 
        WHERE id = id_curso;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
