// models/case_detail_data.dart
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
class CaseDetailData {
  final String descripcionHallazgo;
  final String nivelRiesgo;
  final String? recomendacionesControl;
  final File? foto;
  final Uint8List? firma;
  final Position? ubicacion;
  final DateTime fechaCreacion;
  final bool guardado;

  CaseDetailData({
    required this.descripcionHallazgo,
    required this.nivelRiesgo,
    this.recomendacionesControl,
    this.foto,
    this.firma,
    this.ubicacion,
    required this.fechaCreacion,
    this.guardado = false,
  });

  CaseDetailData copyWith({
    String? descripcionHallazgo,
    String? nivelRiesgo,
    String? recomendacionesControl,
    File? foto,
    Uint8List? firma,
    Position? ubicacion,
    bool? guardado,
  }) {
    return CaseDetailData(
      descripcionHallazgo: descripcionHallazgo ?? this.descripcionHallazgo,
      nivelRiesgo: nivelRiesgo ?? this.nivelRiesgo,
      recomendacionesControl: recomendacionesControl ?? this.recomendacionesControl,
      foto: foto ?? this.foto,
      firma: firma ?? this.firma,
      ubicacion: ubicacion ?? this.ubicacion,
      fechaCreacion: fechaCreacion,
      guardado: guardado ?? this.guardado,
    );
  }
}