-- ACTUALIZACIÓN DE GAMIFICACIÓN DINÁMICA
-- Calcula el tiempo de estudio basado en la duración real del curso

CREATE OR REPLACE FUNCTION actualizar_gamificacion_estudiante()
RETURNS TRIGGER AS $$
DECLARE
    v_hoy DATE := CURRENT_DATE;
    v_ayer DATE := CURRENT_DATE - INTERVAL '1 day';
    v_ultimo_acceso DATE;
    v_curso_id UUID;
    v_horas_totales NUMERIC;
    v_total_lecciones INT;
    v_tiempo_por_leccion NUMERIC;
BEGIN
    -- 1. Obtener el ID del curso al que pertenece la lección
    SELECT m.curso_id INTO v_curso_id 
    FROM lecciones l
    JOIN modulos m ON l.modulo_id = m.id
    WHERE l.id = NEW.leccion_id;

    -- 2. Obtener duración del curso (ej: '20 horas' -> 20) y total de lecciones
    SELECT 
        NULLIF(regexp_replace(duracion_texto, '[^0-9.]', '', 'g'), '')::NUMERIC,
        (SELECT count(*) FROM lecciones l2 JOIN modulos m2 ON l2.modulo_id = m2.id WHERE m2.curso_id = c.id)
    INTO v_horas_totales, v_total_lecciones
    FROM cursos c
    WHERE c.id = v_curso_id;

    -- 3. Calcular tiempo por lección (fallback a 0.25 si falla el cálculo)
    IF v_total_lecciones > 0 AND v_horas_totales > 0 THEN
        v_tiempo_por_leccion := v_horas_totales / v_total_lecciones;
    ELSE
        v_tiempo_por_leccion := 0.25;
    END IF;

    -- 4. Obtener el último acceso del perfil
    SELECT ultimo_acceso_estudio INTO v_ultimo_acceso FROM perfiles WHERE id = NEW.perfil_id;

    -- ACTUALIZAR RACHA (STREAK)
    IF v_ultimo_acceso IS NULL THEN
        UPDATE perfiles SET racha_dias = 1, ultimo_acceso_estudio = v_hoy WHERE id = NEW.perfil_id;
    ELSIF v_ultimo_acceso = v_ayer THEN
        UPDATE perfiles SET racha_dias = racha_dias + 1, ultimo_acceso_estudio = v_hoy WHERE id = NEW.perfil_id;
    ELSIF v_ultimo_acceso < v_ayer THEN
        UPDATE perfiles SET racha_dias = 1, ultimo_acceso_estudio = v_hoy WHERE id = NEW.perfil_id;
    END IF;

    -- ACTUALIZAR HORAS DE ESTUDIO DINÁMICAS
    UPDATE perfiles 
    SET horas_estudio_total = horas_estudio_total + v_tiempo_por_leccion 
    WHERE id = NEW.perfil_id;

    -- ACTUALIZAR META SEMANAL
    INSERT INTO metas_semanales (perfil_id, semana_inicio, horas_estudiadas)
    VALUES (NEW.perfil_id, date_trunc('week', v_hoy)::date, v_tiempo_por_leccion)
    ON CONFLICT (perfil_id, semana_inicio) 
    DO UPDATE SET 
        horas_estudiadas = metas_semanales.horas_estudiadas + v_tiempo_por_leccion,
        porcentaje_alcanzado = LEAST(((metas_semanales.horas_estudiadas + v_tiempo_por_leccion) * 100 / metas_semanales.meta_horas_objetivo), 100);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
