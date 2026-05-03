import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../services/logo_service.dart';
import '../providers/auth_provider.dart';

class AdminController with ChangeNotifier {
  String? _logoUrl;
  bool _loadingLogo = false;
  final bool _loadingUsers = false;
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
    } finally {
      _loadingLogo = false;
      notifyListeners();
    }
  }

  /// Cargar logo de un grupo específico (para uso desde SuperAdmin / GroupAdminScreen).
  Future<void> loadLogoForGroup(String grupoId) async {
    await _loadLogo(grupoId);
  }

  /// Cambiar logo del grupo del usuario actual.
  Future<void> changeLogo(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.grupoId == null) return;
    await changeLogoForGroup(context, authProvider.grupoId!);
  }

  /// Cambiar logo de un grupo específico.
  Future<void> changeLogoForGroup(BuildContext context, String grupoId) async {
    _loadingLogo = true;
    notifyListeners();

    final result = await LogoService.uploadLogo(grupoId);

    _loadingLogo = false;

    if (result.exitoso) {
      _logoUrl = result.url;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.mensaje),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      _errorMessage = result.mensaje;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.mensaje),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Eliminar logo del grupo del usuario actual.
  Future<void> deleteLogo(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.grupoId == null) return;
    await deleteLogoForGroup(context, authProvider.grupoId!);
  }

  /// Eliminar logo de un grupo específico.
  Future<void> deleteLogoForGroup(BuildContext context, String grupoId) async {
    _loadingLogo = true;
    notifyListeners();

    final result = await LogoService.deleteLogo(grupoId);

    _loadingLogo = false;

    if (result.exitoso) {
      _logoUrl = null;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.mensaje),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      _errorMessage = result.mensaje;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.mensaje),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Limpiar errores
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}