import 'package:flutter/material.dart';
import '../models/centro_trabajo_model.dart';

class CentroTrabajoProvider with ChangeNotifier {
  final List<CentroTrabajo> _centros = [];

  List<CentroTrabajo> get centros => _centros;

  List<CentroTrabajo> getCentrosPorEmpresa(String empresaId) {
    return _centros.where((centro) => centro.empresaId == empresaId).toList();
  }

  void agregarCentroTrabajo(CentroTrabajo nuevoCentro) {
    _centros.add(nuevoCentro);
    notifyListeners();
  }

  void eliminarCentroTrabajo(String centroId) {
    _centros.removeWhere((centro) => centro.id == centroId);
    notifyListeners();
  }
}