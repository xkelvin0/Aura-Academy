-- SISTEMA DE GAMIFICACIÓN AURA ACADEMY

-- 1. Agregar campo para rastrear la última vez que estudió
ALTER TABLE perfiles ADD COLUMN IF NOT EXISTS ultimo_acceso_estudio date;

-- 2. Función para actualizar la racha y estadísticas al completar lección
CREATE OR REPLACE FUNCTION actualizar_gamificacion_estudiante()
RETURNS TRIGGER AS $$
DECLARE
    v_hoy DATE := CURRENT_DATE;
    v_ayer DATE := CURRENT_DATE - INTERVAL '1 day';
    v_ultimo_acceso DATE;
BEGIN
    -- Obtener el último acceso del perfil
    SELECT ultimo_acceso_estudio INTO v_ultimo_acceso FROM perfiles WHERE id = NEW.perfil_id;

    -- ACTUALIZAR RACHA (STREAK)
    IF v_ultimo_acceso IS NULL THEN
        -- Primera vez estudiando
        UPDATE perfiles SET racha_dias = 1, ultimo_acceso_estudio = v_hoy WHERE id = NEW.perfil_id;
    ELSIF v_ultimo_acceso = v_ayer THEN
        -- Continuó la racha ayer, incrementamos hoy
        UPDATE perfiles SET racha_dias = racha_dias + 1, ultimo_acceso_estudio = v_hoy WHERE id = NEW.perfil_id;
    ELSIF v_ultimo_acceso < v_ayer THEN
        -- Perdió la racha, reinicia a 1
        UPDATE perfiles SET racha_dias = 1, ultimo_acceso_estudio = v_hoy WHERE id = NEW.perfil_id;
    END IF;
    -- Si v_ultimo_acceso == v_hoy, ya estudió hoy, no tocamos la racha

    -- ACTUALIZAR HORAS DE ESTUDIO (Simulamos 15 min por lección = 0.25h)
    UPDATE perfiles 
    SET horas_estudio_total = horas_estudio_total + 0.25 
    WHERE id = NEW.perfil_id;

    -- ACTUALIZAR META SEMANAL
    -- Buscamos si hay una meta para esta semana (lunes de la semana actual)
    INSERT INTO metas_semanales (perfil_id, semana_inicio, horas_estudiadas)
    VALUES (NEW.perfil_id, date_trunc('week', v_hoy)::date, 0.25)
    ON CONFLICT (perfil_id, semana_inicio) 
    DO UPDATE SET 
        horas_estudiadas = metas_semanales.horas_estudiadas + 0.25,
        porcentaje_alcanzado = LEAST(((metas_semanales.horas_estudiadas + 0.25) * 100 / 10), 100); -- Meta de 10 horas

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger que se dispara al completar una lección
DROP TRIGGER IF EXISTS tr_actualizar_gamificacion ON lecciones_completadas;
CREATE TRIGGER tr_actualizar_gamificacion
AFTER INSERT ON lecciones_completadas
FOR EACH ROW
EXECUTE FUNCTION actualizar_gamificacion_estudiante();

-- 4. RLS para metas_semanales
ALTER TABLE metas_semanales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Usuarios ven sus propias metas" ON metas_semanales;
CREATE POLICY "Usuarios ven sus propias metas" ON metas_semanales
FOR SELECT TO authenticated USING (auth.uid() = perfil_id);
