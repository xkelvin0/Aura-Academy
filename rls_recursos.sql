CREATE POLICY "Lectura pública de recursos" ON recursos_leccion FOR SELECT TO authenticated USING (true);
CREATE POLICY "Instructores manejan recursos" ON recursos_leccion FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1 FROM lecciones 
    JOIN cursos ON cursos.id = lecciones.curso_id 
    WHERE lecciones.id = recursos_leccion.leccion_id 
    AND cursos.instructor_id = auth.uid()
  )
);
