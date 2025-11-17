// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../services/camera_service.dart';
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
  String? _logoUrl;
  bool _loadingLogo = false;

  @override
  void initState() {
    super.initState();
    _loadGrupoInfo();
    _loadLogo();
  }

  void _loadGrupoInfo() {
    final authProvider = context.read<AuthProvider>();
    _grupoId = authProvider.grupoId;
    _grupoNombre = authProvider.grupoNombre;
  }

  void _loadLogo() async {
    if (_grupoId != null) {
      setState(() {
        _loadingLogo = true;
      });
      final logoUrl = await UserService.getGroupLogo(_grupoId!);
      if (mounted) {
        setState(() {
          _logoUrl = logoUrl;
          _loadingLogo = false;
        });
      }
    }
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
            : _buildAdminContent(),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botón para agregar logo
          FloatingActionButton(
            onPressed: _cambiarLogo,
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            mini: true,
            child: const Icon(Icons.image),
            tooltip: 'Cambiar Logo',
          ),
          const SizedBox(height: 16),
          // Botón para agregar usuario
          FloatingActionButton(
            onPressed: _agregarUsuario,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
            tooltip: 'Agregar Usuario',
          ),
        ],
      ),
    );
  }

  Widget _buildAdminContent() {
    return Column(
      children: [
        // Sección del logo
        _buildLogoSection(),
        const SizedBox(height: 16),
        // Lista de usuarios
        Expanded(child: _buildUsersList()),
      ],
    );
  }

  Widget _buildLogoSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.business, color: Colors.purple, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Logo de la Empresa',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        Text(
                          _grupoNombre ?? 'Sin nombre de grupo',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Vista previa del logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: _loadingLogo
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.purple),
                      )
                    : _logoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _logoUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                    SizedBox(height: 8),
                                    Text(
                                      'Error cargando\nlogo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business, color: Colors.grey, size: 40),
                              SizedBox(height: 8),
                              Text(
                                'Sin logo',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
              ),
              
              const SizedBox(height: 16),
              
              // Botones de acción para el logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _cambiarLogo,
                      icon: const Icon(Icons.upload, size: 20),
                      label: const Text('Cambiar Logo'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_logoUrl != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _eliminarLogo,
                        icon: const Icon(Icons.delete, size: 20),
                        label: const Text('Eliminar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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

  void _cambiarLogo() async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Seleccionar Logo'),
          content: const Text('Selecciona el logo de tu empresa desde la galería.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  Navigator.pop(context, 'loading');
                  final fotoData = await CameraService.seleccionarFotoGaleria();
                  if (fotoData != null && fotoData['driveUrl'] != null) {
                    // Enviar el resultado de vuelta
                    if (context.mounted) {
                      Navigator.pop(context, fotoData);
                    }
                  } else {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al seleccionar imagen: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.photo_library),
              label: const Text('Desde Galería'),
            ),
          ],
        ),
      );

      if (result == 'loading') {
        // Mostrar loading mientras se selecciona
        return;
      }

      if (result != null && result['driveUrl'] != null) {
        setState(() {
          _loadingLogo = true;
        });

        // Actualizar el logo en Firestore
        await UserService.updateGroupLogo(_grupoId!, result['driveUrl']!);
        
        // Actualizar el estado local
        setState(() {
          _logoUrl = result['driveUrl'];
          _loadingLogo = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Logo actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _loadingLogo = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al cargar logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _eliminarLogo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Logo'),
        content: const Text('¿Estás seguro de que deseas eliminar el logo de tu empresa?'),
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
      setState(() {
        _loadingLogo = true;
      });

      try {
        await UserService.removeGroupLogo(_grupoId!);
        setState(() {
          _logoUrl = null;
          _loadingLogo = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Logo eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _loadingLogo = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al eliminar logo: $e'),
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