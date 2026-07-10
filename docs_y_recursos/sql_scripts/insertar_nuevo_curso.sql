DO $$
DECLARE
    nuevo_curso_id UUID;
BEGIN
    INSERT INTO cursos (titulo, descripcion, duracion_texto) 
    VALUES ('La Web desde Cero. Aprende Diseño Web con HTML5 y CSS3', 'Curso para aprender HTML5 y CSS3 desde cero.', '6 horas')
    RETURNING id INTO nuevo_curso_id;

    INSERT INTO modulos (curso_id, titulo, orden) VALUES
    (nuevo_curso_id, 'Introducción', 1),
    (nuevo_curso_id, 'Preparar el Entorno de Desarrollo', 2),
    (nuevo_curso_id, 'La Web desde Cero: HTML', 3),
    (nuevo_curso_id, 'La Web Moderna: HTML5', 4),
    (nuevo_curso_id, 'HTML5: La Nueva Estructura', 5),
    (nuevo_curso_id, 'HTML5: Viñetas para Texto', 6),
    (nuevo_curso_id, 'HTML5: Atributos', 7),
    (nuevo_curso_id, 'HTML5: Multimedia', 8),
    (nuevo_curso_id, 'HTML5: Novedades en los Inputs', 9),
    (nuevo_curso_id, 'HTML5: La API Canvas', 10);
END $$;
