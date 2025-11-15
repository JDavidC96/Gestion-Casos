// lib/widgets/group_users_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../widgets/user_form_dialog.dart';

class GroupUsersDialog extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupUsersDialog({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupUsersDialog> createState() => _GroupUsersDialogState();
}

class _GroupUsersDialogState extends State<GroupUsersDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Usuarios de ${widget.groupName}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Reemplazar Expanded con un Container con altura fija
              Container(
                height: 400, // Altura fija o puedes calcular dinámicamente
                child: StreamBuilder<QuerySnapshot>(
                  stream: UserService.getUsersByGroupStream(widget.groupId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No hay usuarios en este grupo'),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
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
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _editarUsuario(doc.id, data),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  onPressed: () => _eliminarUsuario(doc.id, data['displayName']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _agregarUsuario(),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Usuario'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin': return Colors.red;
      case 'admin': return Colors.orange;
      case 'user': return Colors.blue;
      default: return Colors.grey;
    }
  }

  void _agregarUsuario() {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        onSave: (userData) {
          // Se creará automáticamente en este grupo
        },
        isSuperAdmin: true,
        grupoId: widget.groupId,
        grupoNombre: widget.groupName,
      ),
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
        grupoId: widget.groupId,
        grupoNombre: widget.groupName,
      ),
    );
  }

  Future<void> _eliminarUsuario(String userId, String displayName) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar al usuario "$displayName" del grupo?'),
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
              content: Text('Usuario eliminado del grupo'),
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
}