// lib/widgets/group_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';

class GroupCard extends StatelessWidget {
  final String groupId;
  final Map<String, dynamic> groupData;
  final Function(String, String, Map<String, dynamic>) onAction;

  const GroupCard({
    super.key,
    required this.groupId,
    required this.groupData,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
          onSelected: (value) => onAction(value, groupId, groupData),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'users',
              child: ListTile(
                leading: Icon(Icons.open_in_new, size: 20, color: Colors.blue),
                title: Text('Ver Grupo'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'config',
              child: ListTile(
                leading: Icon(Icons.settings, size: 20, color: Colors.green),
                title: Text('Configurar Interfaz'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit, size: 20),
                title: Text('Editar Grupo'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, size: 20, color: Colors.red),
                title: Text('Eliminar Grupo',
                    style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStats() {
    return StreamBuilder<QuerySnapshot>(
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
}