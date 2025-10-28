// widgets/empresa_info_dialog.dart
import 'package:flutter/material.dart';
import '../models/empresa_model.dart';

class EmpresaInfoDialog extends StatelessWidget {
  final Empresa empresa;
  final int cantidadCasos;
  final int casosAbiertos;

  const EmpresaInfoDialog({
    super.key,
    required this.empresa,
    required this.cantidadCasos,
    required this.casosAbiertos,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(empresa.nombre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NIT: ${empresa.nit}'),
          const SizedBox(height: 8),
          Text('Total de casos: $cantidadCasos'),
          Text('Casos abiertos: $casosAbiertos'),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(empresa.icon, color: Colors.blue),
              const SizedBox(width: 8),
              Text('ID: ${empresa.id}'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}