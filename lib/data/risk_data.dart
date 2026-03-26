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
    "categoria": "Mecánico",
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

  //11. EMERGENCIAS
  {
    "categoria": "Emergencias",
    "numeroCategoria": 11,
    "subgrupos": [
      "Extintores",
      "Botiquines",
      "Dispositivos de emergencia",
      "Sistema de emergencia"
    ],
    "icon": Icons.local_hospital_outlined,
    "color": const Color.fromARGB(255, 248, 3, 3),
  },

  //12. ACCIDENTES DE TRÁNSITO
  {
    "categoria": "Accidentes de tránsito",
    "numeroCategoria": 12,
    "subgrupos": [
      "Vehiculo",
      "Condiciones de trabajo",
      "Vias"
    ],
    "icon": Icons.car_crash,
    "color": const Color.fromARGB(255, 0, 0, 0),
  },

  //13. ALTURAS/ESPACIOS CONFINADOS
  {
    "categoria": "Alturas / Espacios confinados",
    "numeroCategoria": 13,
    "subgrupos": [
      "Elementos de proteccion personal",
      "Condiciones de trabajo",
      "Equipos"
    ],
    "icon": Icons.height,
    "color": const Color.fromARGB(255, 8, 235, 76),
  },
];

// ===== ÍCONOS CURADOS PARA CATEGORÍAS PERSONALIZADAS =====
// Se usan nombres string para serializar en Firestore (IconData no es serializable)
const Map<String, IconData> riskIconMap = {
  'warning':       Icons.warning_amber,
  'fire':          Icons.local_fire_department,
  'health_safety': Icons.health_and_safety,
  'construction':  Icons.construction,
  'factory':       Icons.factory,
  'water':         Icons.water_drop,
  'air':           Icons.air,
  'dangerous':     Icons.dangerous,
  'bolt':          Icons.bolt,
  'handyman':      Icons.handyman,
  'truck':         Icons.local_shipping,
  'hospital':      Icons.local_hospital,
  'security':      Icons.security,
  'nature':        Icons.park,
  'thermostat':    Icons.thermostat,
  'hearing':       Icons.hearing,
  'visibility':    Icons.visibility,
  'hand':          Icons.back_hand,
  'masks':         Icons.masks,
  'bug':           Icons.bug_report,
};

// Etiquetas legibles para el picker de íconos
const Map<String, String> riskIconLabels = {
  'warning':       'Advertencia',
  'fire':          'Incendio',
  'health_safety': 'Salud',
  'construction':  'Construcción',
  'factory':       'Industrial',
  'water':         'Agua',
  'air':           'Aire',
  'dangerous':     'Peligroso',
  'bolt':          'Eléctrico',
  'handyman':      'Mantenimiento',
  'truck':         'Transporte',
  'hospital':      'Médico',
  'security':      'Seguridad',
  'nature':        'Natural',
  'thermostat':    'Temperatura',
  'hearing':       'Ruido',
  'visibility':    'Visibilidad',
  'hand':          'Ergonómico',
  'masks':         'Respiratorio',
  'bug':           'Biológico',
};

// ===== MÉTODOS DE AYUDA =====
class RiskData {
  // ── Helpers para la matriz estándar ──────────────────────────────────────

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

  // ── Helpers para íconos serializables ────────────────────────────────────

  /// Convierte un nombre de ícono (string de Firestore) a IconData.
  static IconData getIconDataFromName(String name) =>
      riskIconMap[name] ?? Icons.category;

  // ── Helpers para colores serializables ───────────────────────────────────

  /// Convierte un hex "#RRGGBB" a Color.
  static Color getColorFromHex(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  /// Convierte un Color a hex "#RRGGBB".
  static String getHexFromColor(Color color) =>
      '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  // ── Helpers para lista MEZCLADA (estándar + personalizadas) ──────────────

  /// Siguiente número de categoría disponible para una nueva categoría personalizada.
  static int getNextNumeroCategoria(List<Map<String, dynamic>> personalizadas) {
    if (personalizadas.isEmpty) return matrizPeligros.length + 1;
    final maxNum = personalizadas
        .map((c) => (c['numeroCategoria'] as int?) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return maxNum + 1;
  }

  /// Ícono para una categoría, buscando tanto en la lista estándar como en una
  /// lista personalizada. Las personalizadas usan el campo 'iconName' (String).
  static IconData getIconPorCategoriaFromAll(
      String nombre, List<Map<String, dynamic>> todas) {
    final cat = todas.firstWhere(
      (c) => c['categoria'] == nombre,
      orElse: () => <String, dynamic>{},
    );
    if (cat.isEmpty) return Icons.help;
    if (cat['iconName'] != null) return getIconDataFromName(cat['iconName'] as String);
    return (cat['icon'] as IconData?) ?? Icons.help;
  }

  /// Color para una categoría en la lista mezclada.
  /// Las personalizadas usan el campo 'colorHex' (String).
  static Color getColorPorCategoriaFromAll(
      String nombre, List<Map<String, dynamic>> todas) {
    final cat = todas.firstWhere(
      (c) => c['categoria'] == nombre,
      orElse: () => <String, dynamic>{},
    );
    if (cat.isEmpty) return Colors.grey;
    if (cat['colorHex'] != null) return getColorFromHex(cat['colorHex'] as String);
    return (cat['color'] as Color?) ?? Colors.grey;
  }

  /// Número de categoría en la lista mezclada.
  static int getNumeroCategoriaFromAll(
      String nombre, List<Map<String, dynamic>> todas) {
    final cat = todas.firstWhere(
      (c) => c['categoria'] == nombre,
      orElse: () => <String, dynamic>{},
    );
    return (cat['numeroCategoria'] as int?) ?? 0;
  }

  /// Subgrupos de una categoría en la lista mezclada.
  static List<String> getSubgruposPorCategoriaFromAll(
      String nombre, List<Map<String, dynamic>> todas) {
    final cat = todas.firstWhere(
      (c) => c['categoria'] == nombre,
      orElse: () => <String, dynamic>{},
    );
    if (cat.isEmpty) return [];
    final subs = cat['subgrupos'];
    if (subs is List) return List<String>.from(subs);
    return [];
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