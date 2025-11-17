import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; 
import '../services/user_service.dart';
import '../services/logo_service.dart';
import '../providers/auth_provider.dart';

class AdminController with ChangeNotifier {
  String? _logoUrl;
  bool _loadingLogo = false;
  bool _loadingUsers = false;
  String? _errorMessage;
  
  String? get logoUrl => _logoUrl;
  bool get loadingLogo => _loadingLogo;
  bool get loadingUsers => _loadingUsers;
  String? get errorMessage => _errorMessage;
  
  /// Inicializar controller
  Future<void> initialize(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.grupoId != null) {
      await _loadLogo(authProvider.grupoId!);
    }
  }
  
  /// Cargar logo del grupo
  Future<void> _loadLogo(String grupoId) async {
    try {
      _loadingLogo = true;
      _errorMessage = null;
      notifyListeners();
      
      _logoUrl = await UserService.getGroupLogo(grupoId);
    } catch (e) {
      _errorMessage = 'Error cargando logo: $e';
      print('❌ Error en _loadLogo: $e');
    } finally {
      _loadingLogo = false;
      notifyListeners();
    }
  }
  
  /// Cambiar logo del grupo
  Future<void> changeLogo(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.grupoId == null) return;
      
      _loadingLogo = true;
      notifyListeners();
      final newLogoUrl = await LogoService.uploadLogo(
        XFile('temp'), 
        authProvider.grupoId!,
      );
      
      if (newLogoUrl != null) {
        _logoUrl = newLogoUrl;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Logo actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _errorMessage = 'Error cambiando logo: $e';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al cargar logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _loadingLogo = false;
      notifyListeners();
    }
  }
  
  /// Eliminar logo del grupo
  Future<void> deleteLogo(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.grupoId == null) return;
      
      _loadingLogo = true;
      notifyListeners();
      
      await LogoService.deleteLogo(authProvider.grupoId!);
      _logoUrl = null;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logo eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _errorMessage = 'Error eliminando logo: $e';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al eliminar logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _loadingLogo = false;
      notifyListeners();
    }
  }
  
  /// Limpiar errores
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}