// lib/widgets/case_form_dialog_firebase.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/empresa_model.dart';
import '../services/firebase_service.dart';
import '../data/risk_data.dart';

class CaseFormDialogFirebase extends StatefulWidget {
  final Empresa empresa;
  final String empresaId;
  final String? centroId;

  const CaseFormDialogFirebase({
    super.key,
    required this.empresa,
    required this.empresaId,
    this.centroId,
  });

  @override
  State<CaseFormDialogFirebase> createState() => _CaseFormDialogFirebaseState();
}

class _CaseFormDialogFirebaseState extends State<CaseFormDialogFirebase> {
  String? _tipoPeligroSeleccionado;
  final TextEditingController _tipoPeligroController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _tipoPeligroController.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _tipoPeligroSeleccionado != null &&
      _tipoPeligroController.text.trim().isNotEmpty;

  Future<void> _handleSave() async {
    if (!_isFormValid) {
      String mensajeError = "";
      if (_tipoPeligroSeleccionado == null) {
        mensajeError = "Por favor selecciona un peligro";
      } else if (_tipoPeligroController.text.trim().isEmpty) {
        mensajeError = "Por favor describe el tipo de peligro";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final casoData = {
        'empresaId': widget.empresaId,
        'empresaNombre': widget.empresa.nombre,
        'centroId': widget.centroId,
        'nombre': _tipoPeligroController.text.trim(),
        'tipoRiesgo': _tipoPeligroSeleccionado!,
        'descripcionRiesgo': _tipoPeligroController.text.trim(),
        'nivelRiesgo': 'No aplica',
        'fechaCreacion': FieldValue.serverTimestamp(),
        'cerrado': false,
        'estadoAbierto': {
          'guardado': false,
        },
        'estadoCerrado': {
          'guardado': false,
        },
      };

      final casoId = await FirebaseService.createCaso(casoData);

      if (mounted) {
        Navigator.pop(context);
        
        // Navegar directamente al detalle del caso
        Navigator.pushNamed(
          context,
          '/caseDetail',
          arguments: {
            "casoId": casoId,
            "esNuevo": true,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear caso: $e'),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nuevo Caso - ${widget.empresa.nombre}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Selector de tipo de peligro
              const Text(
                "Peligro *", 
                style: TextStyle(fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _tipoPeligroSeleccionado,
                hint: const Text("Selecciona un tipo de peligro"),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: tiposDePeligro.map((item) {
                  return DropdownMenuItem<String>(
                    value: item["tipo"],
                    child: Row(
                      children: [
                        Icon(item["icon"], color: Colors.blueGrey),
                        const SizedBox(width: 10),
                        Text(item["tipo"]),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _tipoPeligroSeleccionado = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Campo de texto para tipo de peligro
              const Text(
                "Tipo de peligro *", 
                style: TextStyle(fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tipoPeligroController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: "Describe el tipo de peligro...",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              Text(
                _getInstructionText(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Indicador de campos requeridos
              const Text(
                "* Campos requeridos",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),

              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_isFormValid && !_isLoading) ? _handleSave : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Crear Caso'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInstructionText() {
    if (_tipoPeligroSeleccionado == null) {
      return "Primero selecciona un peligro de la lista";
    } else if (_tipoPeligroController.text.isEmpty) {
      return "Ahora describe el tipo de peligro específico";
    } else {
      return "Listo! Puedes crear el caso";
    }
  }
}