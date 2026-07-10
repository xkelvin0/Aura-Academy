-- SISTEMA DE GRADUACIÓN AUTOMÁTICA (Certificados)

-- 1. Función para verificar progreso y generar certificado
CREATE OR REPLACE FUNCTION verificar_graduacion_estudiante()
RETURNS TRIGGER AS $$
DECLARE
    v_curso_id UUID;
    v_total_lecciones INT;
    v_lecciones_completadas INT;
    v_ya_tiene_certificado BOOLEAN;
BEGIN
    -- Obtener el curso al que pertenece la lección completada
    SELECT m.curso_id INTO v_curso_id 
    FROM lecciones l
    JOIN modulos m ON l.modulo_id = m.id
    WHERE l.id = NEW.leccion_id;

    -- 1. Contar total de lecciones del curso
    SELECT COUNT(*) INTO v_total_lecciones
    FROM lecciones l
    JOIN modulos m ON l.modulo_id = m.id
    WHERE m.curso_id = v_curso_id;

    -- 2. Contar lecciones completadas por el usuario en este curso
    SELECT COUNT(DISTINCT lc.leccion_id) INTO v_lecciones_completadas
    FROM lecciones_completadas lc
    JOIN lecciones l ON lc.leccion_id = l.id
    JOIN modulos m ON l.modulo_id = m.id
    WHERE m.curso_id = v_curso_id AND lc.perfil_id = NEW.perfil_id;

    -- 3. Verificar si ya tiene el certificado para no duplicarlo
    SELECT EXISTS (
        SELECT 1 FROM certificados 
        WHERE perfil_id = NEW.perfil_id AND curso_id = v_curso_id
    ) INTO v_ya_tiene_certificado;

    -- 4. Si terminó todo y no tiene el certificado, ¡GRADUACIÓN!
    IF v_lecciones_completadas >= v_total_lecciones AND NOT v_ya_tiene_certificado THEN
        INSERT INTO certificados (perfil_id, curso_id, fecha_emision)
        VALUES (NEW.perfil_id, v_curso_id, NOW());
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Crear el trigger que dispara la función
DROP TRIGGER IF EXISTS tr_verificar_graduacion ON lecciones_completadas;
CREATE TRIGGER tr_verificar_graduacion
AFTER INSERT ON lecciones_completadas
FOR EACH ROW
EXECUTE FUNCTION verificar_graduacion_estudiante();
