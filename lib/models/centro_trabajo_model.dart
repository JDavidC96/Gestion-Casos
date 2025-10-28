class CentroTrabajo {
  final String id;
  final String empresaId;
  final String nombre;
  final String direccion;
  final String tipo; // "Sede Principal", "Sucursal", "Planta", etc.

  CentroTrabajo({
    required this.id,
    required this.empresaId,
    required this.nombre,
    required this.direccion,
    required this.tipo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'empresaId': empresaId,
      'nombre': nombre,
      'direccion': direccion,
      'tipo': tipo,
    };
  }

  factory CentroTrabajo.fromMap(Map<String, dynamic> map) {
    return CentroTrabajo(
      id: map['id'],
      empresaId: map['empresaId'],
      nombre: map['nombre'],
      direccion: map['direccion'],
      tipo: map['tipo'],
    );
  }
}