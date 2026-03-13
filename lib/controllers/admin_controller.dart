import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  /// Cambiar logo del grupo.
  /// LogoService abre el picker y sube la imagen internamente.
  Future<void> changeLogo(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.grupoId == null) return;

      _loadingLogo = true;
      notifyListeners();

      // uploadLogo ya no recibe XFile — abre el picker y sube por su cuenta
      final newLogoUrl = await LogoService.uploadLogo(authProvider.grupoId!);

      if (newLogoUrl != null) {
        _logoUrl = newLogoUrl;
        notifyListeners();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Logo actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // El usuario canceló el selector — no es un error
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se seleccionó ninguna imagen'),
              backgroundColor: Colors.orange,
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
      notifyListeners();

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

  /// Cargar logo de un grupo específico (para uso desde SuperAdmin / GroupAdminScreen).
  /// No depende del AuthProvider — recibe el grupoId directamente.
  Future<void> loadLogoForGroup(String grupoId) async {
    await _loadLogo(grupoId);
  }

  /// Cambiar logo de un grupo específico (para uso desde SuperAdmin).
  /// No depende del AuthProvider — recibe el grupoId directamente.
  Future<void> changeLogoForGroup(BuildContext context, String grupoId) async {
    try {
      _loadingLogo = true;
      notifyListeners();

      final newLogoUrl = await LogoService.uploadLogo(grupoId);

      if (newLogoUrl != null) {
        _logoUrl = newLogoUrl;
        notifyListeners();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Logo actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se seleccionó ninguna imagen'),
              backgroundColor: Colors.orange,
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

  /// Eliminar logo de un grupo específico (para uso desde SuperAdmin).
  /// No depende del AuthProvider — recibe el grupoId directamente.
  Future<void> deleteLogoForGroup(BuildContext context, String grupoId) async {
    try {
      _loadingLogo = true;
      notifyListeners();

      await LogoService.deleteLogo(grupoId);
      _logoUrl = null;
      notifyListeners();

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
}