-- REPARACIÓN DEFINITIVA DE TIPOS EN PERFILES

-- 1. Limpiar racha_dias
ALTER TABLE perfiles ALTER COLUMN racha_dias DROP DEFAULT;
ALTER TABLE perfiles ALTER COLUMN racha_dias TYPE INTEGER USING (CASE WHEN racha_dias ~ '^[0-9]+$' THEN racha_dias::INTEGER ELSE 0 END);
ALTER TABLE perfiles ALTER COLUMN racha_dias SET DEFAULT 0;

-- 2. Limpiar horas_estudio_total
ALTER TABLE perfiles ALTER COLUMN horas_estudio_total DROP DEFAULT;
ALTER TABLE perfiles ALTER COLUMN horas_estudio_total TYPE NUMERIC USING (CASE WHEN horas_estudio_total ~ '^[0-9.]+$' THEN horas_estudio_total::NUMERIC ELSE 0 END);
ALTER TABLE perfiles ALTER COLUMN horas_estudio_total SET DEFAULT 0;

-- 3. Asegurar que no haya NULLs
UPDATE perfiles SET racha_dias = 0 WHERE racha_dias IS NULL;
UPDATE perfiles SET horas_estudio_total = 0 WHERE horas_estudio_total IS NULL;
