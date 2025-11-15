class Case {
  final String id;
  final String empresaId;
  final String empresaNombre;
  final String nombre;
  final String tipoRiesgo;
  final String subgrupoRiesgo;
  final String descripcionRiesgo;
  final String nivelPeligro;
  final DateTime fechaCreacion;
  DateTime? fechaCierre;
  bool cerrado;
  final String? centroId;
  final String? centroNombre;
  final String? grupoId;
  final String? grupoNombre;
  final String? usuarioId;
  final String? usuarioNombre;
  final String? usuarioFirmaBase64;

  Case({
    required this.id,
    required this.empresaId,
    required this.empresaNombre,
    required this.nombre,
    required this.tipoRiesgo,
     this.subgrupoRiesgo = '',
    required this.descripcionRiesgo,
    required this.nivelPeligro,
    required this.fechaCreacion,
    this.fechaCierre,
    this.cerrado = false,
    this.centroId,
    this.centroNombre,
    this.grupoId,
    this.grupoNombre,
    this.usuarioId,
    this.usuarioNombre,
    this.usuarioFirmaBase64,
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
      nivelPeligro: map['nivelPeligro'],
      fechaCreacion: DateTime.parse(map['fechaCreacion']),
      cerrado: map['cerrado'],
    );
  }
}