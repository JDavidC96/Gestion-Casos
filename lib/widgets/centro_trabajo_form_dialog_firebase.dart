// lib/widgets/centro_trabajo_form_dialog_firebase.dart
import 'package:flutter/material.dart';
import '../models/centro_trabajo_model.dart';
import '../services/firebase_service.dart';

class CentroTrabajoFormDialogFirebase extends StatefulWidget {
  final String empresaId;
  final String empresaNombre;
  final String? centroId;
  final CentroTrabajo? centro;
  final String? grupoId;
  final String? grupoNombre;

  const CentroTrabajoFormDialogFirebase({
    super.key,
    required this.empresaId,
    required this.empresaNombre,
    this.centroId,
    this.centro,
    this.grupoId,
    this.grupoNombre,
  });

  @override
  State<CentroTrabajoFormDialogFirebase> createState() => _CentroTrabajoFormDialogFirebaseState();
}

class _CentroTrabajoFormDialogFirebaseState extends State<CentroTrabajoFormDialogFirebase> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  
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

  String? _tipoSeleccionado;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.centro != null) {
      _nombreController.text = widget.centro!.nombre;
      _direccionController.text = widget.centro!.direccion;
      _tipoSeleccionado = widget.centro!.tipo;
    } else {
      _tipoSeleccionado = null;
    }
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
    if (!_formKey.currentState!.validate()) return;
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      final centroData = {
        'empresaId': widget.empresaId,
        'nombre': _nombreController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'tipo': _tipoSeleccionado!,
        'grupoId': widget.grupoId ?? '',
        'grupoNombre': widget.grupoNombre ?? '',
      };

      if (widget.centroId != null) {
        await FirebaseService.updateCentroTrabajo(widget.centroId!, centroData);
      } else {
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
      title: Text(widget.centro == null ? "Nuevo Centro" : "Editar Centro"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Empresa: ${widget.empresaNombre}',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (widget.grupoNombre != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.group, color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Grupo: ${widget.grupoNombre}',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre del centro",
                  border: OutlineInputBorder(),
                  hintText: "Ej: Sede Principal, Planta 1, etc.",
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa el nombre del centro';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _direccionController,
                decoration: const InputDecoration(
                  labelText: "Dirección",
                  border: OutlineInputBorder(),
                  hintText: "Dirección completa del centro",
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa la dirección';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _tipoSeleccionado,
                decoration: const InputDecoration(
                  labelText: "Tipo de centro",
                  border: OutlineInputBorder(),
                ),
                hint: const Text("Selecciona un tipo de centro"),
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
                validator: (value) {
                  if (value == null) {
                    return 'Por favor selecciona un tipo de centro';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _tipoSeleccionado = value;
                  });
                },
              ),
            ],
          ),
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