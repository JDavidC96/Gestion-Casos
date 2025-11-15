// lib/widgets/empresa_form_dialog_firebase.dart - VERSIÓN ACTUALIZADA
import 'package:flutter/material.dart';
import '../models/empresa_model.dart';
import '../services/firebase_service.dart';
import '../utils/icon_utils.dart';

class EmpresaFormDialogFirebase extends StatefulWidget {
  final Empresa? empresa;
  final String? empresaId;
  final Function(Empresa) onSave;
  final String? grupoId;
  final String? grupoNombre;

  const EmpresaFormDialogFirebase({
    super.key,
    this.empresa,
    this.empresaId,
    required this.onSave,
    this.grupoId,
    this.grupoNombre,
  });

  @override
  State<EmpresaFormDialogFirebase> createState() => _EmpresaFormDialogFirebaseState();
}

class _EmpresaFormDialogFirebaseState extends State<EmpresaFormDialogFirebase> {
  final List<Map<String, dynamic>> _iconOptions = [
    {"icon": Icons.factory, "label": "Fábrica", "name": "factory"},
    {"icon": Icons.business, "label": "Oficina", "name": "business"},
    {"icon": Icons.store, "label": "Tienda", "name": "store"},
    {"icon": Icons.apartment, "label": "Edificio", "name": "apartment"},
    {"icon": Icons.local_shipping, "label": "Logística", "name": "local_shipping"},
    {"icon": Icons.warehouse, "label": "Bodega", "name": "warehouse"},
    {"icon": Icons.account_balance, "label": "Banco", "name": "account_balance"},
    {"icon": Icons.school, "label": "Escuela", "name": "school"},
    {"icon": Icons.local_hospital, "label": "Hospital", "name": "local_hospital"},
    {"icon": Icons.restaurant, "label": "Restaurante", "name": "restaurant"},
  ];

  late TextEditingController _nombreController;
  late TextEditingController _nitController;
  late Map<String, dynamic> _selectedOption;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.empresa?.nombre ?? '');
    _nitController = TextEditingController(text: widget.empresa?.nit ?? '');
    
    // Encuentra el icono seleccionado basado en el icono existente
    if (widget.empresa?.icon != null) {
      final iconName = IconUtils.getIconName(widget.empresa!.icon);
      _selectedOption = _iconOptions.firstWhere(
        (opt) => opt["name"] == iconName,
        orElse: () => _iconOptions[0],
      );
    } else {
      _selectedOption = _iconOptions[0];
    }
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

  Future<void> _handleSave() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      final empresaData = {
        'nombre': _nombreController.text.trim(),
        'nit': _nitController.text.trim(),
        'iconName': _selectedOption["name"],
        'icon': _selectedOption["icon"].codePoint,
        // Agregar información del grupo
        'grupoId': widget.grupoId,
        'grupoNombre': widget.grupoNombre,
      };

      if (widget.empresaId != null) {
        // Actualizar empresa existente
        await FirebaseService.updateEmpresa(widget.empresaId!, empresaData);
      } else {
        // Crear nueva empresa con información de grupo
        await FirebaseService.addEmpresaConGrupo(
          empresaData['nombre']!,
          empresaData['nit']!,
          empresaData['iconName']!,
          widget.grupoId,
          widget.grupoNombre,
        );
      }

      final empresa = Empresa(
        id: widget.empresaId ?? "temp",
        nombre: empresaData['nombre']!,
        nit: empresaData['nit']!,
        icon: _selectedOption["icon"],
      );

      widget.onSave(empresa);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.empresaId != null 
                ? 'Empresa actualizada' 
                : 'Empresa creada'),
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
      title: Text(widget.empresa == null ? "Nueva Empresa" : "Editar Empresa"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Información del grupo (solo lectura)
            if (widget.grupoNombre != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.group, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grupo: ${widget.grupoNombre}',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (widget.grupoId != null)
                            Text(
                              'ID: ${widget.grupoId}',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: "Nombre de la empresa",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nitController,
              decoration: const InputDecoration(
                labelText: "NIT",
                border: OutlineInputBorder(),
                hintText: "123456789-0",
              ),
              onChanged: (_) => setState(() {}),
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
              : Text(widget.empresa == null ? "Agregar" : "Guardar"),
        ),
      ],
    );
  }
}