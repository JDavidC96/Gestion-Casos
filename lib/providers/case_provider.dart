import 'package:flutter/material.dart';
import '../models/case_model.dart';

class CaseProvider with ChangeNotifier {
  final List<Case> _casos = [];

  List<Case> get casos => _casos;

  List<Case> getCasosPorEmpresa(String empresaId) {
    return _casos.where((caso) => caso.empresaId == empresaId).toList();
  }

  //Verificar si una empresa tiene casos abiertos
  bool tieneCasosAbiertos(String empresaId) {
    final casosEmpresa = getCasosPorEmpresa(empresaId);
    return casosEmpresa.any((caso) => !caso.cerrado);
  }

  //Obtener cantidad de casos abiertos por empresa
  int cantidadCasosAbiertos(String empresaId) {
    final casosEmpresa = getCasosPorEmpresa(empresaId);
    return casosEmpresa.where((caso) => !caso.cerrado).length;
  }

  void agregarCaso(Case nuevoCaso) {
    _casos.add(nuevoCaso);
    notifyListeners();
  }

  void actualizarCaso(Case casoActualizado) {
    final index = _casos.indexWhere((c) => c.id == casoActualizado.id);
    if (index != -1) {
      _casos[index] = casoActualizado;
      notifyListeners();
    }
  }

  void marcarCasoComoCerrado(String casoId, DateTime fechaCierre) {
    final casoIndex = _casos.indexWhere((c) => c.id == casoId);
    if (casoIndex != -1) {
      _casos[casoIndex].cerrado = true;
      _casos[casoIndex].fechaCierre = fechaCierre;
      notifyListeners();
    }
  }
}
