-- SCRIPT MAESTRO DE RECONSTRUCCIÓN - AURA ACADEMY
DO $$ 
DECLARE 
    v_curso_id uuid;
    v_modulo1_id uuid;
    v_modulo2_id uuid;
    v_modulo3_id uuid;
BEGIN
    -- 1. Insertar Curso (con todos los nuevos campos)
    INSERT INTO public.cursos (
        titulo, subtitulo, descripcion, duracion_texto, 
        categoria_id, instructor_id, precio, precio_original, 
        en_oferta, nivel, thumbnail_url, estado
    )
    VALUES (
        'Fundamentos de HTML: Crea tu primera página web', 
        'Aprende los cimientos de la web desde cero.', 
        'Curso completo desde etiquetas básicas hasta estructura semántica profesional.', 
        '4 horas de video', 
        '330c035e-021c-47a7-b501-58b31c95b425', 
        '99fa3d6e-1bae-4ef9-b966-2f2bc1415a28', 
        0.00, 
        49.50, 
        true, 
        'Principiante', 
        'https://jfbwkofperbqvvvexvsc.supabase.co/storage/v1/object/public/miniaturas/99fa3d6e-1bae-4ef9-b966-2f2bc1415a28/1776371601916.jpg',
        'Publicado'
    ) RETURNING id INTO v_curso_id;

    -- 2. Insertar Módulos
    INSERT INTO public.modulos (curso_id, titulo, orden) 
    VALUES (v_curso_id, 'Los cimientos de la Web', 1) RETURNING id INTO v_modulo1_id;
    
    INSERT INTO public.modulos (curso_id, titulo, orden) 
    VALUES (v_curso_id, 'Estructura y Etiquetas de Texto', 2) RETURNING id INTO v_modulo2_id;
    
    INSERT INTO public.modulos (curso_id, titulo, orden) 
    VALUES (v_curso_id, 'Interactividad y Multimedia', 3) RETURNING id INTO v_modulo3_id;

    -- 3. Insertar Lecciones en Módulo 1
    INSERT INTO public.lecciones (modulo_id, titulo, orden, curso_id) 
    VALUES (v_modulo1_id, 'Fundamentos: Que es html y como viaja la información por internet?', 1, v_curso_id);
    
    INSERT INTO public.lecciones (modulo_id, titulo, orden, curso_id) 
    VALUES (v_modulo1_id, 'Entorno: Instalando VS Code', 2, v_curso_id);
    
    INSERT INTO public.lecciones (modulo_id, titulo, orden, curso_id) 
    VALUES (v_modulo1_id, 'Tu primera línea: ¡Hola Mundo!', 3, v_curso_id);

    RAISE NOTICE 'Curso recreado con éxito. ID: %', v_curso_id;
END $$;
