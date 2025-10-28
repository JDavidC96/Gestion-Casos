// widgets/empresa_form_dialog.dart
import 'package:flutter/material.dart';
import '../models/empresa_model.dart';

class EmpresaFormDialog extends StatefulWidget {
  final Empresa? empresa;
  final Function(Empresa) onSave;

  const EmpresaFormDialog({
    super.key,
    this.empresa,
    required this.onSave,
  });

  @override
  State<EmpresaFormDialog> createState() => _EmpresaFormDialogState();
}

class _EmpresaFormDialogState extends State<EmpresaFormDialog> {
  final List<Map<String, dynamic>> _iconOptions = [
    {"icon": Icons.factory, "label": "Fábrica"},
    {"icon": Icons.business, "label": "Oficina"},
    {"icon": Icons.store, "label": "Tienda"},
    {"icon": Icons.apartment, "label": "Edificio"},
    {"icon": Icons.local_shipping, "label": "Logística"},
  ];

  late TextEditingController _nombreController;
  late TextEditingController _nitController;
  late Map<String, dynamic> _selectedOption;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.empresa?.nombre ?? '');
    _nitController = TextEditingController(text: widget.empresa?.nit ?? '');
    _selectedOption = _iconOptions.firstWhere(
      (opt) => opt["icon"] == widget.empresa?.icon,
      orElse: () => _iconOptions[0],
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _nitController.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _nombreController.text.trim().isNotEmpty &&
      _nitController.text.trim().isNotEmpty;

  void _handleSave() {
    if (_isFormValid) {
      final empresa = Empresa(
        id: widget.empresa?.id ?? "empresa_${DateTime.now().millisecondsSinceEpoch}",
        nombre: _nombreController.text.trim(),
        nit: _nitController.text.trim(),
        icon: _selectedOption["icon"],
      );
      widget.onSave(empresa);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.empresa == null ? "Nueva Empresa" : "Editar Empresa"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: "Nombre de la empresa",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nitController,
              decoration: const InputDecoration(
                labelText: "NIT",
                border: OutlineInputBorder(),
                hintText: "123456789-0",
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedOption,
              decoration: const InputDecoration(
                labelText: "Icono",
                border: OutlineInputBorder(),
              ),
              items: _iconOptions
                  .map((opt) => DropdownMenuItem(
                        value: opt,
                        child: Row(
                          children: [
                            Icon(opt["icon"]),
                            const SizedBox(width: 10),
                            Text(opt["label"]),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedOption = value;
                  });
                }
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
          child: Text(widget.empresa == null ? "Agregar" : "Guardar"), // ← Sin const
        ),
      ],
    );
  }
}