// lib/widgets/user_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/empresas_provider.dart';

class UserCard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userId;
  final Function(String, Map<String, dynamic>) onAction;
  
  const UserCard({
    super.key,
    required this.userData,
    required this.userId,
    required this.onAction,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  @override
  void initState() {
    super.initState();
    // Cargar empresas cuando se inicializa el widget
    _loadEmpresas();
  }

  void _loadEmpresas() {
    final userRole = widget.userData['role'];
    if (userRole == 'inspector' || userRole == 'superinspector') {
      // Usar el provider para cargar las empresas
      final empresasProvider = Provider.of<EmpresasProvider>(context, listen: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        empresasProvider.loadEmpresasForUser(widget.userId);
      });
    }
  }

  @override
  void didUpdateWidget(UserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo recargar si el userId cambió realmente
    if (oldWidget.userId != widget.userId) {
      _loadEmpresas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final empresasProvider = Provider.of<EmpresasProvider>(context);
    
    final isInspector = widget.userData['role'] == 'inspector' || widget.userData['role'] == 'superinspector';
    final puedeAsignarEmpresas = authProvider.isAdmin || authProvider.isSuperAdmin;
    
    // Obtener empresas del provider
    final empresasAsignadas = empresasProvider.getEmpresasUsuario(widget.userId);
    final loadingEmpresas = empresasProvider.isLoading(widget.userId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(widget.userData['role']),
          child: Text(
            widget.userData['displayName']?.toString().substring(0, 1).toUpperCase() ?? 'I',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(widget.userData['displayName'] ?? 'Sin nombre'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.userData['email'] ?? 'Sin email'),
            Text(
              'Cédula: ${widget.userData['cedula']}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Rol: ${_getRoleName(widget.userData['role'])}',
              style: TextStyle(
                fontSize: 12,
                color: _getRoleColor(widget.userData['role']),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isInspector) ...[
              const SizedBox(height: 4),
              _buildEmpresasAsignadasInfo(empresasAsignadas, loadingEmpresas),
            ],
            if (widget.userData['firmaBase64'] != null)
              const Text(
                'Firma: ✅ Registrada',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'assign_empresas') {
              // Ejecutar la acción y esperar a que termine
              await widget.onAction(value, widget.userData);
              // Refrescar las empresas después de asignar
              final empresasProvider = Provider.of<EmpresasProvider>(context, listen: false);
              await empresasProvider.refreshEmpresasForUser(widget.userId);
            } else {
              widget.onAction(value, widget.userData);
            }
          },
          itemBuilder: (context) {
            final menuItems = <PopupMenuEntry<String>>[
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
            ];

            if (puedeAsignarEmpresas && isInspector) {
              menuItems.add(
                const PopupMenuItem(value: 'assign_empresas', child: Text('Asignar Empresas')),
              );
            }

            menuItems.add(
              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            );

            return menuItems;
          },
        ),
      ),
    );
  }

  Widget _buildEmpresasAsignadasInfo(List<String> empresasAsignadas, bool loading) {
    if (loading) {
      return const Text(
        'Empresas: Cargando...',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final count = empresasAsignadas.length;
    if (count == 0) {
      return const Text(
        'Empresas: ❌ Sin asignar',
        style: TextStyle(fontSize: 12, color: Colors.red),
      );
    }

    return Text(
      'Empresas: ✅ $count asignada${count == 1 ? '' : 's'}',
      style: const TextStyle(fontSize: 12, color: Colors.green),
    );
  }
  
  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin': return Colors.red;
      case 'admin': return Colors.orange;
      case 'superinspector': return Colors.purple;
      case 'inspector': return Colors.blue;
      default: return Colors.grey;
    }
  }
  
  String _getRoleName(String role) {
    switch (role) {
      case 'super_admin': return 'Super Admin';
      case 'admin': return 'Administrador';
      case 'superinspector': return 'Super Inspector';
      case 'inspector': return 'Inspector';
      default: return 'Desconocido';
    }
  }
}