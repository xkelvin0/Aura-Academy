-- RESET DE CONTADORES DE LIKES (Sincronización Real)

-- 1. Actualizar el likes_count de cada curso basándose en la cantidad real de filas en lista_deseos
UPDATE cursos c
SET likes_count = (
    SELECT COUNT(*) 
    FROM lista_deseos ld 
    WHERE ld.curso_id = c.id
);

-- 2. Asegurarnos de que no haya NULLs (poner 0 si no hay likes)
UPDATE cursos 
SET likes_count = 0 
WHERE likes_count IS NULL;

-- 3. Opcional: Si quieres resetear vistas a 0 para empezar limpio, descomenta la siguiente linea:
-- UPDATE cursos SET vistas = 0;
