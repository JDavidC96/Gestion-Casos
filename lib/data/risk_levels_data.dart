// data/risk_levels_data.dart
import 'package:flutter/material.dart';

class RiskLevelsData {
  static const List<Map<String, dynamic>> nivelesRiesgo = [
    {
      "nivel": "Bajo",
      "descripcion": "sin incapacidad",
      "color": Colors.green,
    },
    {
      "nivel": "Medio", 
      "descripcion": "con incapacidad",
      "color": Colors.orange,
    },
    {
      "nivel": "Alto",
      "descripcion": "EL, IPP, I o M",
      "color": Colors.red,
    },
    {
      "nivel": "No aplica",
      "descripcion": "no aplica",
      "color": Colors.grey,
    },
  ];

  static String getDescripcionCompleta(String nivel) {
    final nivelData = nivelesRiesgo.firstWhere(
      (item) => item["nivel"] == nivel,
      orElse: () => {"descripcion": "No especificado"},
    );
    return nivelData["descripcion"];
  }

  static Color getColor(String nivel) {
    final nivelData = nivelesRiesgo.firstWhere(
      (item) => item["nivel"] == nivel,
      orElse: () => {"color": Colors.grey},
    );
    return nivelData["color"];
  }
}