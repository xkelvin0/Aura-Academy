import 'package:supabase_flutter/supabase_flutter.dart';

class Categoria {
  final String id;
  final String nombre;
  final String? iconoNombre;
  final String? colorHex;

  Categoria({required this.id, required this.nombre, this.iconoNombre, this.colorHex});

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'],
      nombre: map['nombre'],
      iconoNombre: map['icono_nombre'],
      colorHex: map['color_hex'],
    );
  }
}

class Instructor {
  final String id;
  final String nombre;
  final String? avatarUrl;

  Instructor({required this.id, required this.nombre, this.avatarUrl});

  factory Instructor.fromMap(Map<String, dynamic> map) {
    return Instructor(
      id: map['id'],
      nombre: map['nombre'],
      avatarUrl: map['avatar_url'],
    );
  }
}

class Curso {
  final String id;
  final String titulo;
  final String? subtitulo;
  final String? categoriaId;
  final String? instructorNombre;
  final double precio;
  final double rating;
  final String? thumbnailUrl;
  final String? duracionTexto;
  final bool esDestacado;

  Curso({
    required this.id,
    required this.titulo,
    this.subtitulo,
    this.categoriaId,
    this.instructorNombre,
    required this.precio,
    required this.rating,
    this.thumbnailUrl,
    this.duracionTexto,
    this.esDestacado = false,
  });

  factory Curso.fromMap(Map<String, dynamic> map) {
    return Curso(
      id: map['id'],
      titulo: map['titulo'],
      subtitulo: map['subtitulo'],
      categoriaId: map['categoria_id'],
      instructorNombre: map['instructores']?['nombre'],
      precio: (map['precio'] ?? 0).toDouble(),
      rating: (map['rating'] ?? 0).toDouble(),
      thumbnailUrl: map['thumbnail_url'],
      duracionTexto: map['duracion_texto'],
      esDestacado: map['es_destacado'] ?? false,
    );
  }
}

class Inscripcion {
  final String id;
  final Curso curso;
  final int progresoPorcentaje;
  final int leccionesCompletadas;
  final int totalLecciones;

  Inscripcion({
    required this.id,
    required this.curso,
    required this.progresoPorcentaje,
    required this.leccionesCompletadas,
    required this.totalLecciones,
  });
}
