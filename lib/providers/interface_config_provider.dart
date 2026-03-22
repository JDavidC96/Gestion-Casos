// lib/providers/interface_config_provider.dart
import 'package:flutter/material.dart';
import '../services/interface_config_service.dart';

class InterfaceConfigProvider with ChangeNotifier {
  Map<String, dynamic> _currentConfig = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _loadedGrupoId; // Grupo cuya config está actualmente en memoria

  Map<String, dynamic> get currentConfig => _currentConfig;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get loadedGrupoId => _loadedGrupoId;

  // Cargar configuración para un grupo.
  // Si ya está cargada la config de ese mismo grupo, no hace nada.
  Future<void> loadConfig(String grupoId) async {
    if (grupoId.isEmpty) return;
    if (_loadedGrupoId == grupoId && _currentConfig.isNotEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentConfig = await InterfaceConfigService.getConfigInterfaz(grupoId);
      _loadedGrupoId = grupoId;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error cargando configuración: $e';
      _currentConfig = {};
      _loadedGrupoId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Forzar recarga (útil tras guardar cambios en interface_config_screen)
  Future<void> reloadConfig(String grupoId) async {
    _loadedGrupoId = null;
    await loadConfig(grupoId);
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
        return ThemeMode.light;
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

  // Limpiar estado (llamar al hacer logout para no contaminar otros grupos)
  void clear() {
    _currentConfig = {};
    _errorMessage = null;
    _isLoading = false;
    _loadedGrupoId = null;
    notifyListeners();
  }
}