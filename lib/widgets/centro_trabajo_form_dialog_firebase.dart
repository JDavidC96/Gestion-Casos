// lib/widgets/centro_trabajo_form_dialog_firebase.dart
import 'package:flutter/material.dart';
import '../models/centro_trabajo_model.dart';
import '../services/firebase_service.dart';

class CentroTrabajoFormDialogFirebase extends StatefulWidget {
  final String empresaId;
  final String? centroId;
  final CentroTrabajo? centro;

  const CentroTrabajoFormDialogFirebase({
    super.key,
    required this.empresaId,
    this.centroId,
    this.centro,
  });

  @override
  State<CentroTrabajoFormDialogFirebase> createState() =>
      _CentroTrabajoFormDialogFirebaseState();
}

class _CentroTrabajoFormDialogFirebaseState
    extends State<CentroTrabajoFormDialogFirebase> {
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
  String? _tipoSeleccionado;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.centro?.nombre ?? '');
    _direccionController = TextEditingController(text: widget.centro?.direccion ?? '');
    _tipoSeleccionado = widget.centro?.tipo;
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

  Future<void> _handleSave() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      final centroData = {
        'empresaId': widget.empresaId,
        'nombre': _nombreController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'tipo': _tipoSeleccionado!,
      };

      if (widget.centroId != null) {
        // Actualizar centro existente
        await FirebaseService.updateCentroTrabajo(widget.centroId!, centroData);
      } else {
        // Crear nuevo centro
        await FirebaseService.createCentroTrabajo(centroData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.centroId != null
                ? 'Centro actualizado'
                : 'Centro creado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.centro == null
          ? "Nuevo Centro de Trabajo"
          : "Editar Centro"),
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
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _direccionController,
              decoration: const InputDecoration(
                labelText: "Dirección",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _tipoSeleccionado,
              hint: const Text("Selecciona un tipo de centro"),
              decoration: const InputDecoration(
                labelText: "Tipo de centro",
                border: OutlineInputBorder(),
              ),
              items: _tiposCentro
                  .map((tipo) => DropdownMenuItem(
                        value: tipo,
                        child: Text(tipo),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _tipoSeleccionado = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: (_isFormValid && !_isLoading) ? _handleSave : null,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.centro == null ? "Agregar" : "Guardar"),
        ),
      ],
    );
  }
}