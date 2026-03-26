// lib/providers/interface_config_provider.dart
import 'package:flutter/material.dart';
import '../services/interface_config_service.dart';

class InterfaceConfigProvider with ChangeNotifier {
  Map<String, dynamic> _currentConfig = {};
  List<Map<String, dynamic>> _categoriasPersonalizadas = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _loadedGrupoId; // Grupo cuya config está actualmente en memoria

  Map<String, dynamic> get currentConfig => _currentConfig;
  List<Map<String, dynamic>> get categoriasPersonalizadas => _categoriasPersonalizadas;
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
      _categoriasPersonalizadas =
          await InterfaceConfigService.getCategoriasPersonalizadas(grupoId);
      _loadedGrupoId = grupoId;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error cargando configuración: $e';
      _currentConfig = {};
      _categoriasPersonalizadas = [];
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

  // Obtener color primario actual
  Color getPrimaryColor() {
    final colorName = _currentConfig['colorPrimario'] ?? 'blue';
    return InterfaceConfigService.getColorFromString(colorName);
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

  // ═══════════════════════════════════════════════════════════════════
  //  CRUD CATEGORÍAS PERSONALIZADAS
  // ═══════════════════════════════════════════════════════════════════

  /// Agrega una categoría personalizada y actualiza el estado local.
  Future<void> addCategoriaPersonalizada(
      String grupoId, Map<String, dynamic> cat) async {
    await InterfaceConfigService.addCategoriaPersonalizada(grupoId, cat);
    _categoriasPersonalizadas.add(cat);
    notifyListeners();
  }

  /// Actualiza una categoría personalizada y refleja el cambio localmente.
  Future<void> updateCategoriaPersonalizada(
      String grupoId, Map<String, dynamic> cat) async {
    await InterfaceConfigService.updateCategoriaPersonalizada(grupoId, cat);
    final idx = _categoriasPersonalizadas.indexWhere((c) => c['id'] == cat['id']);
    if (idx != -1) {
      _categoriasPersonalizadas[idx] = cat;
      notifyListeners();
    }
  }

  /// Elimina una categoría personalizada por su id.
  Future<void> deleteCategoriaPersonalizada(
      String grupoId, String categoriaId) async {
    await InterfaceConfigService.deleteCategoriaPersonalizada(grupoId, categoriaId);
    _categoriasPersonalizadas.removeWhere((c) => c['id'] == categoriaId);
    notifyListeners();
  }

  // Limpiar estado (llamar al hacer logout para no contaminar otros grupos)
  void clear() {
    _currentConfig = {};
    _categoriasPersonalizadas = [];
    _errorMessage = null;
    _isLoading = false;
    _loadedGrupoId = null;
    notifyListeners();
  }
}