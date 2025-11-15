// lib/models/centro_trabajo_model.dart
class CentroTrabajo {
  final String id;
  final String empresaId;
  final String nombre;
  final String direccion;
  final String tipo;
  final String grupoId;
  final String grupoNombre;

  CentroTrabajo({
    required this.id,
    required this.empresaId,
    required this.nombre,
    required this.direccion,
    required this.tipo,
    required this.grupoId,
    required this.grupoNombre,
  });

  Map<String, dynamic> toMap() {
    return {
      'empresaId': empresaId,
      'nombre': nombre,
      'direccion': direccion,
      'tipo': tipo,
      'grupoId': grupoId,
      'grupoNombre': grupoNombre,
    };
  }

  factory CentroTrabajo.fromMap(String id, Map<String, dynamic> map) {
    return CentroTrabajo(
      id: id,
      empresaId: map['empresaId'] ?? '',
      nombre: map['nombre'] ?? '',
      direccion: map['direccion'] ?? '',
      tipo: map['tipo'] ?? '',
      grupoId: map['grupoId'] ?? '',
      grupoNombre: map['grupoNombre'] ?? '',
    );
  }
}