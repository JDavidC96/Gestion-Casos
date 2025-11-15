// lib/screens/super_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_form_dialog.dart';
import '../widgets/group_form_dialog.dart';
import '../widgets/group_users_dialog.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Super Administrador"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  authProvider.userData!['displayName'] ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                if (authProvider.grupoNombre != null)
                  Text(
                    authProvider.grupoNombre!,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: _selectedIndex == 0 
                  ? _buildUsersList()
                  : _buildGroupsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectedIndex == 0 ? _agregarUsuario : _agregarGrupo,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() => _selectedIndex = 0),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedIndex == 0 ? Colors.orange : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Usuarios'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() => _selectedIndex = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedIndex == 1 ? Colors.orange : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Grupos'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: UserService.getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people, size: 80, color: Colors.white70),
                const SizedBox(height: 16),
                const Text(
                  'No hay usuarios registrados',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getRoleColor(data['role']),
                    child: Text(
                      data['displayName']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(data['displayName'] ?? 'Sin nombre'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['email'] ?? 'Sin email'),
                      Text(
                        'Rol: ${data['role']} • Cédula: ${data['cedula']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (data['grupoNombre'] != null)
                        Text(
                          'Grupo: ${data['grupoNombre']}',
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleUserAction(value, doc.id, data),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGroupsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: UserService.getGruposStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group, size: 80, color: Colors.white70),
                const SizedBox(height: 16),
                const Text(
                  'No hay grupos registrados',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return _buildGroupCard(doc.id, data);
            },
          ),
        );
      },
    );
  }

  Widget _buildGroupCard(String groupId, Map<String, dynamic> groupData) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.group, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupData['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        groupData['descripcion'] ?? 'Sin descripción',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleGroupAction(value, groupId, groupData),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'users', child: Text('Gestionar Usuarios')),
                    const PopupMenuItem(value: 'config', child: Text('Configurar Interfaz')),
                    const PopupMenuItem(value: 'edit', child: Text('Editar Grupo')),
                    const PopupMenuItem(value: 'delete', child: Text('Eliminar Grupo')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: UserService.getUsersByGroupStream(groupId),
              builder: (context, userSnapshot) {
                final userCount = userSnapshot.hasData ? userSnapshot.data!.docs.length : 0;
                final adminCount = userSnapshot.hasData 
                  ? userSnapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['role'] == 'admin' || data['role'] == 'super_admin';
                    }).length
                  : 0;

                return Row(
                  children: [
                    _buildCountChip('$userCount Usuarios', Icons.people),
                    const SizedBox(width: 8),
                    _buildCountChip('$adminCount Admins', Icons.admin_panel_settings),
                    const SizedBox(width: 8),
                    _buildCountChip('Activo', Icons.check_circle, color: Colors.green),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountChip(String text, IconData icon, {Color? color}) {
    return Chip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
      avatar: Icon(icon, size: 16, color: color),
      backgroundColor: Colors.grey[100],
      visualDensity: VisualDensity.compact,
    );
  }

  void _agregarUsuario() {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        onSave: (userData) {
          // El usuario se creará con los datos proporcionados
        },
        isSuperAdmin: true,
      ),
    );
  }

  void _agregarGrupo() {
    showDialog(
      context: context,
      builder: (context) => GroupFormDialog(
        onSave: (groupData) {
          UserService.createGrupo(groupData['nombre'], groupData['descripcion']);
        },
      ),
    );
  }

  void _handleUserAction(String action, String userId, Map<String, dynamic> userData) {
    switch (action) {
      case 'edit':
        _editarUsuario(userId, userData);
        break;
      case 'delete':
        _confirmarEliminarUsuario(userId, userData['displayName']);
        break;
    }
  }

  void _handleGroupAction(String action, String groupId, Map<String, dynamic> groupData) {
    switch (action) {
      case 'users':
        _gestionarUsuarios(groupId, groupData);
        break;
      case 'config':
        _configurarInterfaz(groupId, groupData);
        break;
      case 'edit':
        _editarGrupo(groupId, groupData);
        break;
      case 'delete':
        _confirmarEliminarGrupo(groupId, groupData['nombre']);
        break;
    }
  }

  void _gestionarUsuarios(String groupId, Map<String, dynamic> groupData) {
    showDialog(
      context: context,
      builder: (context) => GroupUsersDialog(
        groupId: groupId,
        groupName: groupData['nombre'],
      ),
    );
  }

  void _configurarInterfaz(String groupId, Map<String, dynamic> groupData) {
  // Navegar a pantalla de configuración de interfaz
  Navigator.pushNamed(
    context,
    '/interface_config',
    arguments: {
      'groupId': groupId,
      'groupData': groupData,
    },
  );
}

  void _editarUsuario(String userId, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        userData: userData,
        userId: userId,
        onSave: (updatedData) {
          UserService.updateUser(userId, updatedData);
        },
        isSuperAdmin: true,
      ),
    );
  }

  void _editarGrupo(String groupId, Map<String, dynamic> groupData) {
    showDialog(
      context: context,
      builder: (context) => GroupFormDialog(
        groupId: groupId,
        groupData: groupData,
        onSave: (updatedData) {
          UserService.updateGrupo(groupId, updatedData);
        },
      ),
    );
  }

  Future<void> _confirmarEliminarUsuario(String userId, String displayName) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar al usuario "$displayName"?'),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuario eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
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

  Future<void> _confirmarEliminarGrupo(String groupId, String groupName) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar el grupo "$groupName"? Esta acción eliminará todos los usuarios y datos asociados.'),
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
        await UserService.deleteGrupo(groupId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grupo eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
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

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin': return Colors.red;
      case 'admin': return Colors.orange;
      case 'user': return Colors.blue;
      default: return Colors.grey;
    }
  }
}