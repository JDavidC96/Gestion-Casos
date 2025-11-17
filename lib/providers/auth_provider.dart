// lib/providers/auth_provider.dart 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _userData;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get userData => _userData;
  bool get isAuthenticated => _user != null;

  // NUEVOS GETTERS PARA GRUPOS Y ROLES ACTUALIZADOS
  String? get grupoId => _userData?['grupoId'];
  String? get grupoNombre => _userData?['grupoNombre'];
  bool get isSuperAdmin => _userData?['role'] == 'super_admin';
  bool get isAdmin => _userData?['role'] == 'admin' || isSuperAdmin;
  bool get isSuperInspector => _userData?['role'] == 'superinspector';
  bool get isInspector => _userData?['role'] == 'inspector' || isSuperInspector;
  
  // Método para verificar si es cualquier tipo de inspector
  bool get isAnyInspector => isInspector || isSuperInspector;
  
  // PERMISOS ESPECÍFICOS SEGÚN JERARQUÍA
  bool get canManageGroups => isSuperAdmin;
  bool get canManageAllUsers => isSuperAdmin;
  bool get canManageGroupUsers => isAdmin || isSuperAdmin;
  bool get canManageLogo => isAdmin || isSuperAdmin;
  bool get canAssignInspectors => isAdmin || isSuperAdmin;
  bool get canViewAllCompanies => isSuperInspector || isAdmin || isSuperAdmin;
  bool get canViewAssignedCompanies => isInspector || isSuperInspector;
  bool get canCreateCases => isAnyInspector;
  bool get canCloseCases => isAnyInspector;
  bool get canGenerateReports => isAnyInspector;
  bool get canManageUsers => isAdmin || isSuperAdmin;

  // NUEVO: Empresas asignadas para inspectores
  List<String> get empresasAsignadas {
    final empresas = _userData?['empresasAsignadas'] as List<dynamic>?;
    return empresas?.cast<String>() ?? [];
  }

  // Verificar permisos de acceso a recursos
  bool puedeAccederRecurso(String? recursoGrupoId) {
    if (isSuperAdmin || isSuperInspector) return true; // Super roles ven todo
    if (recursoGrupoId == null) return false; // Recursos sin grupo no son accesibles
    return recursoGrupoId == grupoId; // Solo ve recursos de su grupo
  }

  // Verificar si puede editar un recurso
  bool puedeEditarRecurso(String? recursoGrupoId) {
    if (isSuperAdmin || isAdmin || isSuperInspector) return true;
    return recursoGrupoId == grupoId && isAdmin;
  }

  // NUEVO: Verificar acceso a empresa específica
  bool puedeAccederAEmpresa(String empresaId) {
    if (isSuperAdmin || isAdmin) return true; // Super admin y admin ven todas las empresas
    
    // Para inspectores, verificar si la empresa está en sus empresas asignadas
    return empresasAsignadas.contains(empresaId);
  }

  // Verificar permisos para recursos específicos
  bool puedeGestionarGrupo(String? grupoId) {
    return isSuperAdmin || (isAdmin && this.grupoId == grupoId);
  }

  bool puedeGestionarUsuario(String? userGrupoId) {
    return isSuperAdmin || (isAdmin && this.grupoId == userGrupoId);
  }

  bool puedeVerEmpresa(String? empresaGrupoId) {
    return isSuperAdmin || 
           isSuperInspector || 
           (isAdmin && this.grupoId == empresaGrupoId) ||
           (isInspector && this.grupoId == empresaGrupoId);
  }

  AuthProvider() {
    // Escuchar cambios de autenticación
    FirebaseService.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserData();
      } else {
        _userData = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData() async {
    if (_user != null) {
      _userData = await FirebaseService.getUserData(_user!.uid);
      notifyListeners();
    }
  }

  Future<bool> createSuperUser(String email, String password, String displayName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await FirebaseService.createSuperUser(email, password, displayName);
      _user = user;
      await _loadUserData();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await FirebaseService.signInWithEmail(email, password);
      _user = user;
      await _loadUserData();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Método para recuperación de contraseña
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirebaseService.resetPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Inicio de sesión con Google MODIFICADO
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await FirebaseService.signInWithGoogle();
      _isLoading = false;
      
      if (result != null && result['needsRegistration'] == false) {
        // Usuario existe, cargar datos
        _user = result['user'];
        await _loadUserData();
      }
      
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = _getGoogleErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Método para completar registro con Google
  Future<bool> completeGoogleRegistration(
    String userId,
    String cedula,
    String displayName,
    String email,
    String? firmaBase64,
    String? grupoId,
    String? grupoNombre,
    String role,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirebaseService.completeGoogleRegistration(
        userId,
        cedula,
        displayName,
        email,
        firmaBase64,
        grupoId,
        grupoNombre,
        role,
      );
      
      _isLoading = false;
      await _loadUserData();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await FirebaseService.signOut();
    await FirebaseService.signOutGoogle(); // Cerrar sesión de Google también
    _user = null;
    _userData = null;
    notifyListeners();
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No se encontró un usuario con ese correo';
        case 'wrong-password':
          return 'Contraseña incorrecta';
        case 'email-already-in-use':
          return 'El correo ya está registrado';
        case 'weak-password':
          return 'La contraseña es muy débil';
        case 'invalid-email':
          return 'Correo electrónico inválido';
        case 'user-disabled':
          return 'Este usuario ha sido deshabilitado';
        case 'too-many-requests':
          return 'Demasiados intentos. Intenta más tarde';
        case 'missing-android-pkg-name':
        case 'missing-ios-bundle-id':
          return 'Configuración de la app incompleta. Contacta al administrador';
        default:
          return 'Error de autenticación: ${error.message}';
      }
    }
    return 'Error desconocido: $error';
  }

  // Método para manejar errores específicos de Google
  String _getGoogleErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
          return 'Ya existe una cuenta con el mismo email pero con otro método de autenticación';
        case 'invalid-credential':
          return 'Credenciales de Google inválidas';
        case 'operation-not-allowed':
          return 'El inicio de sesión con Google no está habilitado';
        case 'user-disabled':
          return 'Este usuario ha sido deshabilitado';
        case 'user-not-found':
          return 'No se encontró el usuario';
        case 'wrong-password':
          return 'Contraseña incorrecta';
        case 'invalid-verification-code':
          return 'Código de verificación inválido';
        case 'invalid-verification-id':
          return 'ID de verificación inválido';
        case 'google-signin-cancelled':
          return 'El inicio de sesión con Google fue cancelado';
        case 'network-request-failed':
          return 'Error de conexión. Verifica tu internet';
        default:
          return 'Error con Google Sign-In: ${error.message}';
      }
    }
    return 'Error desconocido: $error';
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}