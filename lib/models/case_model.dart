class Case {
  final String id;
  final String empresaId;
  final String empresaNombre;
  final String nombre;
  final String tipoRiesgo;
  final String descripcionRiesgo;
  final String nivelRiesgo;
  final DateTime fechaCreacion;
  DateTime? fechaCierre;
  bool cerrado;

  Case({
    required this.id,
    required this.empresaId,
    required this.empresaNombre,
    required this.nombre,
    required this.tipoRiesgo,
    required this.descripcionRiesgo,
    required this.nivelRiesgo,
    required this.fechaCreacion,
    this.fechaCierre,
    this.cerrado = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'empresaId': empresaId,
      'empresaNombre': empresaNombre,
      'nombre': nombre,
      'tipoRiesgo': tipoRiesgo,
      'descripcionRiesgo': descripcionRiesgo,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'cerrado': cerrado,
    };
  }

  factory Case.fromMap(Map<String, dynamic> map) {
    return Case(
      id: map['id'],
      empresaId: map['empresaId'],
      empresaNombre: map['empresaNombre'],
      nombre: map['nombre'],
      tipoRiesgo: map['tipoRiesgo'],
      descripcionRiesgo: map['descripcionRiesgo'],
      nivelRiesgo: map['nivelRiesgo'],
      fechaCreacion: DateTime.parse(map['fechaCreacion']),
      cerrado: map['cerrado'],
    );
  }
}