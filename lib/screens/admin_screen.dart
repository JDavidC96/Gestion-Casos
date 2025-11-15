// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_form_dialog.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String? _grupoId;
  String? _grupoNombre;

  @override
  void initState() {
    super.initState();
    _loadGrupoInfo();
  }

  void _loadGrupoInfo() {
    final authProvider = context.read<AuthProvider>();
    _grupoId = authProvider.grupoId;
    _grupoNombre = authProvider.grupoNombre;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Administración de Usuarios"),
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
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
            tooltip: 'Ir al Inicio',
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
        child: _grupoId == null 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _buildUsersList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarUsuario,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: UserService.getUsersByGroupStream(_grupoId!),
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
                  'No hay usuarios en tu grupo',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _agregarUsuario,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar Primer Usuario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // Filtrar usuarios: solo mostrar usuarios normales del grupo actual
        final usuariosFiltrados = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] == 'user' && data['grupoId'] == _grupoId;
        }).toList();

        if (usuariosFiltrados.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 80, color: Colors.white70),
                const SizedBox(height: 16),
                const Text(
                  'No hay usuarios normales en tu grupo',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Grupo: $_grupoNombre',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _agregarUsuario,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar Primer Usuario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del grupo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Grupo Actual:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            _grupoNombre ?? 'Sin nombre',
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
                        '${usuariosFiltrados.length} usuario${usuariosFiltrados.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Lista de usuarios
              Expanded(
                child: ListView.builder(
                  itemCount: usuariosFiltrados.length,
                  itemBuilder: (context, index) {
                    final doc = usuariosFiltrados[index];
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
                              'Cédula: ${data['cedula']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (data['firmaBase64'] != null)
                              const Text(
                                'Firma: ✅ Registrada',
                                style: TextStyle(fontSize: 12, color: Colors.green),
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
              ),
            ],
          ),
        );
      },
    );
  }

  void _agregarUsuario() {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        onSave: (userData) {
          // El usuario se creará automáticamente en el grupo del admin
        },
        isSuperAdmin: false, // Importante: los admins NO son super admins
        grupoId: _grupoId,
        grupoNombre: _grupoNombre,
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

  void _editarUsuario(String userId, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        userData: userData,
        userId: userId,
        onSave: (updatedData) {
          UserService.updateUser(userId, updatedData);
        },
        isSuperAdmin: false, // Importante: los admins NO son super admins
        grupoId: _grupoId,
        grupoNombre: _grupoNombre,
      ),
    );
  }

  Future<void> _confirmarEliminarUsuario(String userId, String displayName) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar al usuario "$displayName" de tu grupo?'),
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

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin': return Colors.red;
      case 'admin': return Colors.orange;
      case 'user': return Colors.blue;
      default: return Colors.grey;
    }
  }
}