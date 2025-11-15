// widgets/empresa_options_bottom_sheet.dart - VERSIÓN ACTUALIZADA
import 'package:flutter/material.dart';

class EmpresaOptionsBottomSheet extends StatelessWidget {
  final VoidCallback onViewInfo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool puedeEditar;

  const EmpresaOptionsBottomSheet({
    super.key,
    required this.onViewInfo,
    required this.onEdit,
    required this.onDelete,
    this.puedeEditar = true,
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
        if (puedeEditar) ...[
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
        if (!puedeEditar)
          ListTile(
            leading: const Icon(Icons.lock, color: Colors.grey),
            title: const Text(
              "Sin permisos de edición",
              style: TextStyle(color: Colors.grey),
            ),
            onTap: null,
          ),
      ],
    );
  }
}