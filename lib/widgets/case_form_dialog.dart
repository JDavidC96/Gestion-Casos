// widgets/case_form_dialog.dart - VERSIÓN COMPATIBLE
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/case_model.dart';
import '../models/empresa_model.dart';
import '../providers/case_provider.dart';
import '../data/risk_data.dart'; // Cambiar import

class CaseFormDialog extends StatefulWidget {
  final Empresa empresa;

  const CaseFormDialog({
    super.key,
    required this.empresa,
  });

  @override
  State<CaseFormDialog> createState() => _CaseFormDialogState();
}

class _CaseFormDialogState extends State<CaseFormDialog> {
  String? _tipoPeligroSeleccionado;
  final TextEditingController _tipoPeligroController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Inicializar con la primera categoría
    _tipoPeligroSeleccionado = RiskData.getCategorias().isNotEmpty 
        ? RiskData.getCategorias()[0] 
        : null;
  }

  @override
  void dispose() {
    _tipoPeligroController.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _tipoPeligroSeleccionado != null &&
      _tipoPeligroController.text.trim().isNotEmpty;

  void _handleSave() {
    if (_isFormValid) {
      final nuevoCaso = Case(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        empresaId: widget.empresa.id,
        empresaNombre: widget.empresa.nombre,
        nombre: _tipoPeligroController.text.trim(),
        tipoRiesgo: _tipoPeligroSeleccionado!,
        descripcionRiesgo: _tipoPeligroController.text.trim(),
        nivelPeligro: "No aplica",
        fechaCreacion: DateTime.now(),
      );

      final caseProvider = Provider.of<CaseProvider>(context, listen: false);
      caseProvider.agregarCaso(nuevoCaso);

      Navigator.pop(context);
      _navigateToCaseDetail(nuevoCaso);
    } else {
      // Mostrar mensaje de error específico
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
    }
  }

  void _navigateToCaseDetail(Case caso) {
    Navigator.pushNamed(
      context,
      '/caseDetail',
      arguments: {
        "caso": caso,
      },
    );
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

              // Selector de tipo de peligro (PRIMERO)
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
                items: RiskData.getCategorias().map((categoria) {
                  return DropdownMenuItem<String>(
                    value: categoria,
                    child: Row(
                      children: [
                        Icon(
                          RiskData.getIconPorCategoria(categoria),
                          color: RiskData.getColorPorCategoria(categoria),
                        ),
                        const SizedBox(width: 10),
                        Text(categoria),
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

              // Campo de texto para tipo de peligro (DESPUÉS)
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
                  setState(() {}); // Forzar rebuild para actualizar el botón
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isFormValid ? _handleSave : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Crear Caso'),
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