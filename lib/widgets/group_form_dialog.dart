// lib/widgets/group_form_dialog.dart
import 'package:flutter/material.dart';

class GroupFormDialog extends StatefulWidget {
  final String? groupId;
  final Map<String, dynamic>? groupData;
  final Function(Map<String, dynamic>) onSave;

  const GroupFormDialog({
    super.key,
    this.groupId,
    this.groupData,
    required this.onSave,
  });

  @override
  State<GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<GroupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.groupData != null) {
      _nombreController.text = widget.groupData!['nombre'] ?? '';
      _descripcionController.text = widget.groupData!['descripcion'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.groupId == null ? 'Crear Grupo' : 'Editar Grupo'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Grupo',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El nombre es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La descripción es requerida';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardarGrupo,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _guardarGrupo() {
    if (!_formKey.currentState!.validate()) return;

    final groupData = {
      'nombre': _nombreController.text.trim(),
      'descripcion': _descripcionController.text.trim(),
    };

    widget.onSave(groupData);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
}