// widgets/empresa_info_dialog_centros.dart
import 'package:flutter/material.dart';
import '../models/empresa_model.dart';

class EmpresaInfoDialogCentros extends StatelessWidget {
  final Empresa empresa;
  final int cantidadCentros;

  const EmpresaInfoDialogCentros({
    super.key,
    required this.empresa,
    required this.cantidadCentros,
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
          Text('Centros de trabajo: $cantidadCentros'),
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