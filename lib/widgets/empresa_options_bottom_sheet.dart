// widgets/empresa_options_bottom_sheet.dart
import 'package:flutter/material.dart';

class EmpresaOptionsBottomSheet extends StatelessWidget {
  final VoidCallback onViewInfo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EmpresaOptionsBottomSheet({
    super.key,
    required this.onViewInfo,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text("Ver información"),
          onTap: onViewInfo,
        ),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text("Editar"),
          onTap: onEdit,
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text("Eliminar"),
          onTap: onDelete,
        ),
      ],
    );
  }
}