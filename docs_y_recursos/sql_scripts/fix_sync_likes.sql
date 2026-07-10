-- 1. Función para manejar los likes automáticamente
CREATE OR REPLACE FUNCTION manejar_likes_curso()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- Si alguien agrega a favoritos, sumamos 1 al curso
        UPDATE cursos 
        SET likes_count = COALESCE(likes_count, 0) + 1 
        WHERE id = NEW.curso_id;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        -- Si alguien lo quita, restamos 1
        UPDATE cursos 
        SET likes_count = GREATEST(COALESCE(likes_count, 0) - 1, 0) 
        WHERE id = OLD.curso_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Crear el trigger que dispara la función
DROP TRIGGER IF EXISTS tr_manejar_likes ON lista_deseos;
CREATE TRIGGER tr_manejar_likes
AFTER INSERT OR DELETE ON lista_deseos
FOR EACH ROW
EXECUTE FUNCTION manejar_likes_curso();

-- 3. Función para incrementar vistas de forma segura (RPC)
CREATE OR REPLACE FUNCTION incrementar_vistas_curso(id_curso UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE cursos 
    SET vistas = COALESCE(vistas, 0) + 1 
    WHERE id = id_curso;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
