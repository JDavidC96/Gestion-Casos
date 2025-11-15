// lib/services/interface_config_service.dart - VERSIÓN CORREGIDA
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InterfaceConfigService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Configuración por defecto
  static final Map<String, dynamic> _defaultConfig = {
    'mostrarCasosCerrados': true,
    'mostrarEstadisticas': true,
    'habilitarFotos': true,
    'habilitarFirmas': true,
    'mostrarnivelPeligro': true,
    'mostrarUbicacion': true,
    'tema': 'default',
    'colorPrimario': 'blue',
    'habilitarReportes': true,
    'mostrarCentrosTrabajo': true,
    'limiteFotos': 5,
    'tamanoMaximoFoto': 10, // MB
    'habilitarNotificaciones': true,
    'mostrarFechas': true,
    'habilitarBusqueda': true,
    'ordenamiento': 'fecha', // 'fecha', 'nombre', 'riesgo'
  };

  // Obtener configuración de interfaz por grupo
  static Future<Map<String, dynamic>> getConfigInterfaz(String grupoId) async {
    try {
      final doc = await _firestore.collection('grupos').doc(grupoId).get();
      
      if (!doc.exists) {
        return _defaultConfig;
      }

      final configData = doc.data()?['configInterfaz'] as Map<String, dynamic>?;
      
      if (configData == null) {
        return _defaultConfig;
      }

      // Combinar con configuración por defecto para asegurar que todos los campos existan
      return {..._defaultConfig, ...configData};
    } catch (e) {
      print('Error obteniendo configuración de interfaz: $e');
      return _defaultConfig;
    }
  }

  // Guardar configuración de interfaz
  static Future<void> saveConfigInterfaz(
    String grupoId, 
    Map<String, dynamic> configData,
  ) async {
    try {
      await _firestore.collection('grupos').doc(grupoId).update({
        'configInterfaz': configData,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error guardando configuración de interfaz: $e');
      rethrow;
    }
  }

  // Obtener configuración en tiempo real (Stream)
  static Stream<Map<String, dynamic>> getConfigInterfazStream(String grupoId) {
    return _firestore
        .collection('grupos')
        .doc(grupoId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return _defaultConfig;
          }

          final configData = snapshot.data()?['configInterfaz'] as Map<String, dynamic>?;
          
          if (configData == null) {
            return _defaultConfig;
          }

          return {..._defaultConfig, ...configData};
        })
        .handleError((error) {
          print('Error en stream de configuración: $error');
          return _defaultConfig;
        });
  }

  // Verificar si una característica está habilitada
  static Future<bool> isFeatureEnabled(String grupoId, String feature) async {
    final config = await getConfigInterfaz(grupoId);
    return config[feature] ?? true;
  }

  // Obtener color primario del grupo
  static Future<Color> getPrimaryColor(String grupoId) async {
    final config = await getConfigInterfaz(grupoId);
    final colorName = config['colorPrimario'] ?? 'blue';
    return getColorFromString(colorName); // CAMBIO: Método público
  }

  // Obtener tema del grupo
  static Future<ThemeMode> getThemeMode(String grupoId) async {
    final config = await getConfigInterfaz(grupoId);
    final tema = config['tema'] ?? 'default';
    
    switch (tema) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  // Métodos de utilidad para colores - AHORA PÚBLICO
  static Color getColorFromString(String colorName) {
    switch (colorName) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'red':
        return Colors.red;
      case 'teal':
        return Colors.teal;
      case 'indigo':
        return Colors.indigo;
      case 'pink':
        return Colors.pink;
      case 'amber':
        return Colors.amber;
      case 'cyan':
        return Colors.cyan;
      case 'deepOrange':
        return Colors.deepOrange;
      case 'brown':
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  // Obtener lista de colores disponibles
  static List<Map<String, dynamic>> getAvailableColors() {
    return [
      {'name': 'blue', 'label': 'Azul', 'color': Colors.blue},
      {'name': 'green', 'label': 'Verde', 'color': Colors.green},
      {'name': 'orange', 'label': 'Naranja', 'color': Colors.orange},
      {'name': 'purple', 'label': 'Morado', 'color': Colors.purple},
      {'name': 'red', 'label': 'Rojo', 'color': Colors.red},
      {'name': 'teal', 'label': 'Verde Azulado', 'color': Colors.teal},
      {'name': 'indigo', 'label': 'Índigo', 'color': Colors.indigo},
      {'name': 'pink', 'label': 'Rosa', 'color': Colors.pink},
      {'name': 'amber', 'label': 'Ámbar', 'color': Colors.amber},
      {'name': 'cyan', 'label': 'Cian', 'color': Colors.cyan},
      {'name': 'deepOrange', 'label': 'Naranja Oscuro', 'color': Colors.deepOrange},
      {'name': 'brown', 'label': 'Marrón', 'color': Colors.brown},
    ];
  }

  // Obtener lista de temas disponibles
  static List<Map<String, dynamic>> getAvailableThemes() {
    return [
      {'value': 'default', 'label': 'Sistema'},
      {'value': 'light', 'label': 'Claro'},
      {'value': 'dark', 'label': 'Oscuro'},
    ];
  }

  // Validar configuración
  static Map<String, dynamic> validateConfig(Map<String, dynamic> config) {
    final validatedConfig = <String, dynamic>{};
    
    // Validar valores booleanos
    final booleanFields = [
      'mostrarCasosCerrados', 'mostrarEstadisticas', 'habilitarFotos',
      'habilitarFirmas', 'mostrarnivelPeligro', 'mostrarUbicacion',
      'habilitarReportes', 'mostrarCentrosTrabajo', 'habilitarNotificaciones',
      'mostrarFechas', 'habilitarBusqueda'
    ];
    
    for (var field in booleanFields) {
      validatedConfig[field] = config[field] is bool ? config[field] : true;
    }
    
    // Validar tema
    final availableThemes = ['default', 'light', 'dark'];
    validatedConfig['tema'] = availableThemes.contains(config['tema']) 
        ? config['tema'] 
        : 'default';
    
    // Validar color primario
    final availableColors = getAvailableColors().map((c) => c['name']).toList();
    validatedConfig['colorPrimario'] = availableColors.contains(config['colorPrimario'])
        ? config['colorPrimario']
        : 'blue';
    
    // Validar límites numéricos
    validatedConfig['limiteFotos'] = _validateNumber(config['limiteFotos'], 1, 20, 5);
    validatedConfig['tamanoMaximoFoto'] = _validateNumber(config['tamanoMaximoFoto'], 1, 50, 10);
    
    // Validar ordenamiento
    final availableOrders = ['fecha', 'nombre', 'riesgo'];
    validatedConfig['ordenamiento'] = availableOrders.contains(config['ordenamiento'])
        ? config['ordenamiento']
        : 'fecha';
    
    return validatedConfig;
  }

  static int _validateNumber(dynamic value, int min, int max, int defaultValue) {
    if (value is int && value >= min && value <= max) {
      return value;
    }
    return defaultValue;
  }

  // Crear configuración inicial para un nuevo grupo
  static Future<void> initializeGroupConfig(String grupoId) async {
    try {
      await _firestore.collection('grupos').doc(grupoId).set({
        'configInterfaz': _defaultConfig,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error inicializando configuración del grupo: $e');
      rethrow;
    }
  }

  // Eliminar configuración de grupo (al eliminar el grupo)
  static Future<void> deleteGroupConfig(String grupoId) async {
    try {
      await _firestore.collection('grupos').doc(grupoId).delete();
    } catch (e) {
      print('Error eliminando configuración del grupo: $e');
      rethrow;
    }
  }
}