// widgets/centro_trabajo_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/centro_trabajo_model.dart';
import '../providers/centro_trabajo_provider.dart';

class CentroTrabajoFormDialog extends StatefulWidget {
  final String empresaId;

  const CentroTrabajoFormDialog({
    super.key,
    required this.empresaId,
  });

  @override
  State<CentroTrabajoFormDialog> createState() => _CentroTrabajoFormDialogState();
}

class _CentroTrabajoFormDialogState extends State<CentroTrabajoFormDialog> {
  final List<String> _tiposCentro = [
    "Sede Principal",
    "Sucursal",
    "Planta de Producción",
    "Oficina Regional",
    "Almacén",
    "Bodega",
    "Punto de Venta",
    "Otro"
  ];

  late TextEditingController _nombreController;
  late TextEditingController _direccionController;
  late String? _tipoSeleccionado;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _direccionController = TextEditingController();
    _tipoSeleccionado = null; // Vacío por defecto
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _nombreController.text.trim().isNotEmpty &&
      _direccionController.text.trim().isNotEmpty &&
      _tipoSeleccionado != null;

  void _handleSave() {
    if (_isFormValid) {
      final nuevoCentro = CentroTrabajo(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        empresaId: widget.empresaId,
        nombre: _nombreController.text.trim(),
        direccion: _direccionController.text.trim(),
        tipo: _tipoSeleccionado!,
        grupoId: '', 
        grupoNombre: '', 
      );

      final centroProvider = Provider.of<CentroTrabajoProvider>(context, listen: false);
      centroProvider.agregarCentroTrabajo(nuevoCentro);

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Nuevo Centro de Trabajo"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: "Nombre del centro",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _direccionController,
              decoration: const InputDecoration(
                labelText: "Dirección",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _tipoSeleccionado,
              hint: const Text("Selecciona un tipo de centro"),
              decoration: const InputDecoration(
                labelText: "Tipo de centro",
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text("Selecciona un tipo"),
                ),
                ..._tiposCentro
                    .map((tipo) => DropdownMenuItem(
                          value: tipo,
                          child: Text(tipo),
                        ))
                    .toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _tipoSeleccionado = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Por favor selecciona un tipo de centro';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: _isFormValid ? _handleSave : null,
          child: const Text("Agregar"),
        ),
      ],
    );
  }
}