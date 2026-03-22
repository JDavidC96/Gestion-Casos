// lib/models/case_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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
      'subgrupoRiesgo': subgrupoRiesgo,
      'descripcionRiesgo': descripcionRiesgo,
      'nivelPeligro': nivelPeligro,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'cerrado': cerrado,
      'centroId': centroId,
      'centroNombre': centroNombre,
      'grupoId': grupoId,
      'grupoNombre': grupoNombre,
      'usuarioId': usuarioId,
      'usuarioNombre': usuarioNombre,
    };
  }

  /// Factory desde un Map genérico (ej: JSON o navegación).
  factory Case.fromMap(Map<String, dynamic> map) {
    return Case(
      id: map['id'] ?? '',
      empresaId: map['empresaId'] ?? '',
      empresaNombre: map['empresaNombre'] ?? '',
      nombre: map['nombre'] ?? '',
      tipoRiesgo: map['tipoRiesgo'] ?? '',
      subgrupoRiesgo: map['subgrupoRiesgo'] ?? '',
      descripcionRiesgo: map['descripcionRiesgo'] ?? '',
      nivelPeligro: map['nivelPeligro'] ?? '',
      fechaCreacion: map['fechaCreacion'] is DateTime
          ? map['fechaCreacion']
          : DateTime.tryParse(map['fechaCreacion']?.toString() ?? '') ?? DateTime.now(),
      fechaCierre: map['fechaCierre'] is DateTime
          ? map['fechaCierre']
          : DateTime.tryParse(map['fechaCierre']?.toString() ?? ''),
      cerrado: map['cerrado'] ?? false,
      centroId: map['centroId'],
      centroNombre: map['centroNombre'],
      grupoId: map['grupoId'],
      grupoNombre: map['grupoNombre'],
      usuarioId: map['usuarioId'],
      usuarioNombre: map['usuarioNombre'],
    );
  }

  /// Factory desde un QueryDocumentSnapshot de Firestore.
  /// Maneja Timestamp, lee nivelPeligro del estadoAbierto si existe,
  /// y asigna el doc.id como id del caso.
  factory Case.fromFirestore(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>?;

    // El nivel de peligro actualizado puede estar en estadoAbierto
    final nivelActualizado = estadoAbierto?['nivelPeligro'] as String?
        ?? data['nivelPeligro'] as String?
        ?? '';

    return Case(
      id: doc.id,
      empresaId: data['empresaId'] ?? '',
      empresaNombre: data['empresaNombre'] ?? '',
      nombre: data['nombre'] ?? '',
      tipoRiesgo: data['tipoRiesgo'] ?? '',
      subgrupoRiesgo: data['subgrupoRiesgo'] ?? '',
      descripcionRiesgo: data['descripcionRiesgo'] ?? '',
      nivelPeligro: nivelActualizado,
      fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaCierre: (data['fechaCierre'] as Timestamp?)?.toDate(),
      cerrado: data['cerrado'] ?? false,
      centroId: data['centroId'],
      centroNombre: data['centroNombre'],
      grupoId: data['grupoId'],
      grupoNombre: data['grupoNombre'],
      usuarioId: data['usuarioId'],
      usuarioNombre: data['usuarioNombre'],
    );
  }
}