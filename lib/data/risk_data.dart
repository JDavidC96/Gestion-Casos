// data/risk_data.dart - VERSIÓN COMPATIBLE
import 'package:flutter/material.dart';

// ===== MATRIZ COMPLETA DE PELIGROS =====
final List<Map<String, dynamic>> matrizPeligros = [
  // 1. FÍSICO
  {
    "categoria": "Físico",
    "numeroCategoria": 1,
    "subgrupos": [
      "Ruido",
      "Iluminación",
      "Vibraciones",
      "Temperaturas extremas (frío/calor)",
      "Radiaciones ionizantes",
      "Radiaciones no ionizantes",
      "Presiones anormales",
      "Ventilación inadecuada"
    ],
    "icon": Icons.volume_up,
    "color": Colors.blue,
  },
  
  // 2. QUÍMICO
  {
    "categoria": "Químico",
    "numeroCategoria": 2,
    "subgrupos": [
      "Polvos orgánicos",
      "Polvos inorgánicos",
      "Líquidos",
      "Gases",
      "Vapores",
      "Humos",
      "Neblinas",
      "Fibras",
      "Material particulado",
      "Sustancias corrosivas, tóxicas o irritantes"
    ],
    "icon": Icons.science,
    "color": Colors.orange,
  },
  
  // 3. BIOLÓGICO
  {
    "categoria": "Biológico",
    "numeroCategoria": 3,
    "subgrupos": [
      "Virus",
      "Bacterias",
      "Hongos",
      "Parásitos",
      "Picaduras o mordeduras de animales",
      "Material biológico contaminado (sangre, fluidos)"
    ],
    "icon": Icons.biotech,
    "color": Colors.green,
  },
  
  // 4. PSICOSOCIAL
  {
    "categoria": "Psicosocial",
    "numeroCategoria": 4,
    "subgrupos": [
      "Carga mental",
      "Monotonía o repetitividad",
      "Falta de control sobre el trabajo",
      "Exceso de trabajo",
      "Conflictos interpersonales",
      "Acoso laboral",
      "Turnos nocturnos",
      "Inestabilidad laboral"
    ],
    "icon": Icons.psychology,
    "color": Colors.pink,
  },
  
  // 5. BIOMECÁNICO / ERGONÓMICO
  {
    "categoria": "Biomecánico / Ergonómico",
    "numeroCategoria": 5,
    "subgrupos": [
      "Posturas forzadas",
      "Movimientos repetitivos",
      "Manipulación manual de cargas",
      "Esfuerzo físico excesivo",
      "Trabajo de precisión",
      "Diseño inadecuado del puesto de trabajo"
    ],
    "icon": Icons.accessibility_new,
    "color": Colors.purple,
  },
  
  // 6. SEGURIDAD / MECÁNICO
  {
    "categoria": "Seguridad / Mecánico",
    "numeroCategoria": 6,
    "subgrupos": [
      "Caídas a distinto o mismo nivel",
      "Golpes o choques",
      "Atrapamientos",
      "Cortes o pinchazos",
      "Proyección de partículas",
      "Contacto con superficies calientes o frías",
      "Uso de herramientas o máquinas sin protección"
    ],
    "icon": Icons.build,
    "color": Colors.brown,
  },
  
  // 7. ELÉCTRICO
  {
    "categoria": "Eléctrico",
    "numeroCategoria": 7,
    "subgrupos": [
      "Contacto directo o indirecto con corriente eléctrica",
      "Sobrecargas",
      "Descargas electrostáticas",
      "Campos eléctricos"
    ],
    "icon": Icons.electrical_services,
    "color": Colors.yellow,
  },
  
  // 8. LOCATIVO
  {
    "categoria": "Locativo",
    "numeroCategoria": 8,
    "subgrupos": [
      "Superficies irregulares o resbalosas",
      "Falta de orden y aseo",
      "Iluminación deficiente",
      "Espacios reducidos",
      "Almacenamiento inadecuado",
      "Falta de señalización"
    ],
    "icon": Icons.location_city,
    "color": Colors.blueGrey,
  },
  
  // 9. PÚBLICO / SOCIAL
  {
    "categoria": "Público / Social",
    "numeroCategoria": 9,
    "subgrupos": [
      "Violencia externa (robos, agresiones)",
      "Riesgo público",
      "Desastres naturales",
      "Agresiones verbales o físicas de terceros"
    ],
    "icon": Icons.people,
    "color": Colors.red,
  },
  
  // 10. FENÓMENOS NATURALES
  {
    "categoria": "Fenómenos Naturales",
    "numeroCategoria": 10,
    "subgrupos": [
      "Sismos",
      "Inundaciones",
      "Deslizamientos",
      "Rayos",
      "Incendios forestales",
      "Erupciones volcánicas"
    ],
    "icon": Icons.cloud,
    "color": Colors.deepOrange,
  },
];

// ===== MÉTODOS DE AYUDA =====
class RiskData {
  static List<String> getCategorias() {
    return matrizPeligros.map((categoria) => categoria["categoria"] as String).toList();
  }
  
  static Map<String, dynamic>? getCategoriaPorNombre(String nombre) {
    return matrizPeligros.firstWhere(
      (categoria) => categoria["categoria"] == nombre,
      orElse: () => {},
    );
  }
  
  static List<String> getSubgruposPorCategoria(String categoriaNombre) {
    final categoria = getCategoriaPorNombre(categoriaNombre);
    return categoria != null ? List<String>.from(categoria["subgrupos"] ?? []) : [];
  }
  
  static IconData getIconPorCategoria(String categoriaNombre) {
    final categoria = getCategoriaPorNombre(categoriaNombre);
    return categoria != null ? categoria["icon"] as IconData : Icons.help;
  }
  
  static Color getColorPorCategoria(String categoriaNombre) {
    final categoria = getCategoriaPorNombre(categoriaNombre);
    return categoria != null ? categoria["color"] as Color : Colors.grey;
  }
  
  static int getNumeroCategoria(String categoriaNombre) {
    final categoria = getCategoriaPorNombre(categoriaNombre);
    return categoria != null ? categoria["numeroCategoria"] as int : 0;
  }
}

// ===== COMPATIBILIDAD CON CÓDIGO EXISTENTE =====
// Mantener la variable original para compatibilidad
final List<Map<String, dynamic>> tiposDePeligro = matrizPeligros.map((categoria) {
  return {
    "tipo": categoria["categoria"],
    "icon": categoria["icon"],
  };
}).toList();