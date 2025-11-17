// lib/providers/empresas_provider.dart
import 'package:flutter/foundation.dart';
import '../services/user_service.dart';

class EmpresasProvider with ChangeNotifier {
  final Map<String, List<String>> _empresasPorUsuario = {};
  final Map<String, bool> _loadingStates = {};
  final Map<String, bool> _hasLoadedStates = {}; // Nuevo: para trackear si ya se cargó

  Future<void> loadEmpresasForUser(String userId) async {
    // Si ya está cargando o ya se cargó, no hacer nada
    if (_loadingStates[userId] == true || _hasLoadedStates[userId] == true) return;
    
    _loadingStates[userId] = true;
    notifyListeners();

    try {
      final empresas = await UserService.getEmpresasAsignadas(userId);
      _empresasPorUsuario[userId] = empresas;
      _hasLoadedStates[userId] = true; // Marcar como cargado
    } catch (e) {
      print('Error cargando empresas para usuario $userId: $e');
      _empresasPorUsuario[userId] = [];
      _hasLoadedStates[userId] = true; // Marcar como cargado incluso en error
    } finally {
      _loadingStates[userId] = false;
      notifyListeners();
    }
  }

  Future<void> refreshEmpresasForUser(String userId) async {
    // Resetear estados para forzar recarga
    _empresasPorUsuario.remove(userId);
    _loadingStates.remove(userId);
    _hasLoadedStates.remove(userId);
    await loadEmpresasForUser(userId);
  }

  List<String> getEmpresasUsuario(String userId) {
    return _empresasPorUsuario[userId] ?? [];
  }

  bool isLoading(String userId) {
    return _loadingStates[userId] ?? false; // Cambiar de true a false por defecto
  }

  void updateEmpresasUsuario(String userId, List<String> empresas) {
    _empresasPorUsuario[userId] = empresas;
    _hasLoadedStates[userId] = true; // Marcar como cargado
    notifyListeners();
  }

  void clear() {
    _empresasPorUsuario.clear();
    _loadingStates.clear();
    _hasLoadedStates.clear();
  }
}