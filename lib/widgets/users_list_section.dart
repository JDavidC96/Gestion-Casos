import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../services/admin_service.dart';
import '../widgets/user_form_dialog.dart';
import '../widgets/user_card.dart';
import '../widgets/assign_empresas_dialog.dart';
import '../providers/auth_provider.dart';
import '../providers/empresas_provider.dart';

class UsersListSection extends StatelessWidget {
  final String grupoId;
  final String? grupoNombre;
  final VoidCallback? onAddUser;

  /// Cuando es true, siempre filtra por grupoId sin importar el rol.
  /// Usar desde GroupAdminScreen para que el SuperAdmin vea solo
  /// los usuarios del grupo seleccionado, no todos los del sistema.
  final bool filtrarPorGrupo;
  
  const UsersListSection({
    super.key,
    required this.grupoId,
    required this.grupoNombre,
    this.onAddUser,
    this.filtrarPorGrupo = false,
  });

  /// true = vista global (todos los usuarios). false = filtrado por grupo.
  bool _esVistaGlobal(AuthProvider auth) =>
      auth.isSuperAdmin && !filtrarPorGrupo;
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final empresasProvider = Provider.of<EmpresasProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del grupo
          _buildGroupInfo(context, authProvider),
          const SizedBox(height: 16),
          
          // Lista de usuarios/inspectores
          Expanded(
            child: _buildUsersList(authProvider, empresasProvider),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGroupInfo(BuildContext context, AuthProvider authProvider) {
    final global = _esVistaGlobal(authProvider);
    return StreamBuilder<int>(
      stream: global
          ? _getTotalUsersCount() 
          : AdminService.getInspectorCount(grupoId),
      builder: (context, snapshot) {
        final userCount = snapshot.data ?? 0;
        final title = global ? 'Todos los Usuarios del Sistema' : 'Usuarios del Grupo';
        final subtitle = global ? 'Vista de Super Administrador' : grupoNombre ?? 'Sin nombre';
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                global ? Icons.supervised_user_circle : Icons.group, 
                color: Colors.white70
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  '$userCount ${_getUserLabel(userCount, authProvider)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: global ? Colors.purple : Colors.orange,
              ),
            ],
          ),
        );
      },
    );
  }
  
  Stream<int> _getTotalUsersCount() {
    return UserService.getUsersStream().map((snapshot) => snapshot.docs.length);
  }
  
  String _getUserLabel(int count, AuthProvider authProvider) {
    if (authProvider.isSuperAdmin) {
      return count == 1 ? 'usuario' : 'usuarios';
    } else {
      return count == 1 ? 'inspector' : 'inspectores';
    }
  }
  
  Widget _buildUsersList(AuthProvider authProvider, EmpresasProvider empresasProvider) {
    final global = _esVistaGlobal(authProvider);
    return StreamBuilder<QuerySnapshot>(
      stream: global
          ? UserService.getUsersStream() 
          : UserService.getUsersByGroupStream(grupoId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(authProvider);
        }

        // Filtrar usuarios según contexto
        final usuariosFiltrados = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          if (global) {
            // Vista global (SuperAdmin en su pantalla): todos excepto a sí mismo
            return data['uid'] != authProvider.user?.uid;
          } else {
            // Vista de grupo: todos los usuarios del grupo
            final userGrupoId = data['grupoId'] as String?;
            return userGrupoId == grupoId;
          }
        }).toList();

        if (usuariosFiltrados.isEmpty) {
          return _buildNoUsersState(authProvider);
        }

        return ListView.builder(
          itemCount: usuariosFiltrados.length,
          itemBuilder: (context, index) {
            final doc = usuariosFiltrados[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return UserCard(
              userData: data,
              userId: doc.id,
              onAction: (action, userData) => _handleUserAction(
                context, action, doc.id, userData, authProvider, empresasProvider // Pasar empresasProvider
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            error,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(AuthProvider authProvider) {
    final global = _esVistaGlobal(authProvider);
    final message = global
        ? 'No hay usuarios en el sistema' 
        : 'No hay usuarios en este grupo';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          if (!global) ...[
            const SizedBox(height: 8),
            Text(
              'Grupo: $grupoNombre',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildNoUsersState(AuthProvider authProvider) {
    final global = _esVistaGlobal(authProvider);
    final message = global
        ? 'No hay usuarios que mostrar' 
        : 'No hay usuarios en este grupo';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          if (!global) ...[
            const SizedBox(height: 8),
            Text(
              'Grupo: $grupoNombre',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
  
  void _handleUserAction(
    BuildContext context, 
    String action, 
    String userId, 
    Map<String, dynamic> userData,
    AuthProvider authProvider,
    EmpresasProvider empresasProvider // Añadir parámetro
  ) {
    switch (action) {
      case 'edit':
        _editarUsuario(context, userId, userData, authProvider);
        break;
      case 'assign_empresas':
        _asignarEmpresas(context, userId, userData, authProvider, empresasProvider);
        break;
      case 'delete':
        _confirmarEliminarUsuario(context, userId, userData['displayName'], authProvider);
        break;
    }
  }
  
  void _asignarEmpresas(
  BuildContext context, 
  String userId, 
  Map<String, dynamic> userData, 
  AuthProvider authProvider,
  EmpresasProvider empresasProvider 
) {
  // Verificación adicional de seguridad
  final puedeAsignar = authProvider.isAdmin || authProvider.isSuperAdmin;
  final esInspector = userData['role'] == 'inspector' || userData['role'] == 'superinspector';
  
  if (!puedeAsignar) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No tienes permisos para asignar empresas'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  if (!esInspector) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solo se pueden asignar empresas a inspectores'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (context) => AssignEmpresasDialog(
      userId: userId,
      userDisplayName: userData['displayName'] ?? 'Usuario',
      empresasActuales: (userData['empresasAsignadas'] as List<dynamic>?)?.cast<String>() ?? [],
      empresasProvider: empresasProvider, 
    ),
  ).then((result) {
    // Solo refrescar si se guardaron cambios exitosamente
    if (result == true && context.mounted) {
      empresasProvider.refreshEmpresasForUser(userId);
    }
  });
}
  
  void _editarUsuario(
    BuildContext context, 
    String userId, 
    Map<String, dynamic> userData,
    AuthProvider authProvider
  ) {
    // Verificar permisos antes de editar
    if (!_tienePermisosParaGestionarUsuario(authProvider, userData)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para editar este usuario'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        userData: userData,
        userId: userId,
        onSave: (updatedData) {
          UserService.updateUser(userId, updatedData);
        },
        isSuperAdmin: authProvider.isSuperAdmin,
        grupoId: userData['grupoId'] ?? grupoId,
        grupoNombre: userData['grupoNombre'] ?? grupoNombre,
      ),
    );
  }
  
  Future<void> _confirmarEliminarUsuario(
    BuildContext context, 
    String userId, 
    String displayName,
    AuthProvider authProvider
  ) async {
    final userType = authProvider.isSuperAdmin ? 'usuario' : 'inspector';
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar al $userType "$displayName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await UserService.deleteUser(userId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userType eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  bool _tienePermisosParaGestionarUsuario(AuthProvider authProvider, Map<String, dynamic> userData) {
    if (authProvider.isSuperAdmin) {
      return true; // Super admin puede gestionar cualquier usuario
    }
    
    if (authProvider.isAdmin) {
      // Admin solo puede gestionar usuarios de su grupo
      final userGrupoId = userData['grupoId'] as String?;
      return userGrupoId == authProvider.grupoId;
    }
    
    return false; // Inspectores no pueden gestionar usuarios
  }
}