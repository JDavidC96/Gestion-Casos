// lib/providers/interface_config_provider.dart - VERSIÓN CORREGIDA
import 'package:flutter/material.dart';
import '../services/interface_config_service.dart';

class InterfaceConfigProvider with ChangeNotifier {
  Map<String, dynamic> _currentConfig = {};
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> get currentConfig => _currentConfig;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Cargar configuración para un grupo
  Future<void> loadConfig(String grupoId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentConfig = await InterfaceConfigService.getConfigInterfaz(grupoId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error cargando configuración: $e';
      _currentConfig = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Guardar configuración
  Future<bool> saveConfig(String grupoId, Map<String, dynamic> config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final validatedConfig = InterfaceConfigService.validateConfig(config);
      await InterfaceConfigService.saveConfigInterfaz(grupoId, validatedConfig);
      _currentConfig = validatedConfig;
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Error guardando configuración: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Actualizar un valor específico
  void updateConfigValue(String key, dynamic value) {
    _currentConfig[key] = value;
    notifyListeners();
  }

  // Verificar si una característica está habilitada
  bool isFeatureEnabled(String feature) {
    return _currentConfig[feature] ?? true;
  }

  // Obtener color primario actual - CORREGIDO
  Color getPrimaryColor() {
    final colorName = _currentConfig['colorPrimario'] ?? 'blue';
    return InterfaceConfigService.getColorFromString(colorName); // Usar método público
  }

  // Obtener tema actual
  ThemeMode getThemeMode() {
    final tema = _currentConfig['tema'] ?? 'default';
    
    switch (tema) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  // Obtener límite de fotos
  int getPhotoLimit() {
    return _currentConfig['limiteFotos'] ?? 5;
  }

  // Obtener tamaño máximo de foto
  int getMaxPhotoSize() {
    return _currentConfig['tamanoMaximoFoto'] ?? 10;
  }

  // Obtener tipo de ordenamiento
  String getSortingType() {
    return _currentConfig['ordenamiento'] ?? 'fecha';
  }

  // Limpiar estado
  void clear() {
    _currentConfig = {};
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}