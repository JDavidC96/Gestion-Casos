// lib/widgets/case_form_dialog_firebase.dart
import 'package:flutter/material.dart';
import '../models/empresa_model.dart';
import '../services/firebase_service.dart';
import '../data/risk_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CaseFormDialogFirebase extends StatefulWidget {
  final Empresa empresa;
  final String empresaId;
  final String? centroId;
  final String? centroNombre;
  final String? grupoId;
  final String? grupoNombre;

  const CaseFormDialogFirebase({
    super.key,
    required this.empresa,
    required this.empresaId,
    this.centroId,
    this.centroNombre,
    this.grupoId,
    this.grupoNombre,
  });

  @override
  State<CaseFormDialogFirebase> createState() => _CaseFormDialogFirebaseState();
}

class _CaseFormDialogFirebaseState extends State<CaseFormDialogFirebase> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();

  String _selectedCategoria = 'Físico';
  String? _selectedSubgrupo;
  String _selectednivelPeligro = 'Medio';
  bool _isLoading = false;

  // Configuración de la interfaz
  Map<String, dynamic> _configInterfaz = {};
  bool _mostrarNivelPeligroEnDialog = false;

  List<String> get _categorias => RiskData.getCategorias();
  
  List<String> get _subgrupos => RiskData.getSubgruposPorCategoria(_selectedCategoria);

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
    if (_subgrupos.isNotEmpty) {
      _selectedSubgrupo = _subgrupos[0];
    }
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final grupoId = authProvider.grupoId;
      
      if (grupoId != null) {
        final grupoDoc = await FirebaseFirestore.instance
            .collection('grupos')
            .doc(grupoId)
            .get();
            
        if (grupoDoc.exists) {
          final config = grupoDoc.data()?['configInterfaz'] ?? {};
          setState(() {
            _configInterfaz = config;
            _mostrarNivelPeligroEnDialog = config['mostrarNivelPeligroEnDialog'] ?? false;
            _selectednivelPeligro = config['nivelPeligroDefault'] ?? 'Medio';
          });
        }
      }
    } catch (e) {
      print('Error cargando configuración: $e');
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _nombreController.text.trim().isNotEmpty &&
      _selectedSubgrupo != null;

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final casoData = {
        'empresaId': widget.empresaId,
        'empresaNombre': widget.empresa.nombre,
        'nombre': _nombreController.text.trim(),
        'tipoRiesgo': _selectedCategoria,
        'subgrupoRiesgo': _selectedSubgrupo,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'cerrado': false,
        'centroId': widget.centroId,
        'centroNombre': widget.centroNombre,
        'grupoId': widget.grupoId,
        'grupoNombre': widget.grupoNombre,
        'numeroCategoria': RiskData.getNumeroCategoria(_selectedCategoria),
      };

      // Solo agregar nivel de peligro si está habilitado en la configuración
      if (_mostrarNivelPeligroEnDialog) {
        casoData['nivelPeligro'] = _selectednivelPeligro;
      }

      await FirebaseService.createCaso(casoData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caso creado exitosamente'),
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

  Color _getnivelPeligroColor(String nivel) {
    switch (nivel) {
      case 'Bajo':
        return Colors.green;
      case 'Medio':
        return Colors.orange;
      case 'Alto':
        return Colors.red[400]!;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCategoriaSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedCategoria,
      decoration: const InputDecoration(
        labelText: "Categoría de Peligro",
        border: OutlineInputBorder(),
      ),
      items: _categorias
          .map((categoria) => DropdownMenuItem(
                value: categoria,
                child: Row(
                  children: [
                    Icon(
                      RiskData.getIconPorCategoria(categoria),
                      color: RiskData.getColorPorCategoria(categoria),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(categoria),
                  ],
                ),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCategoria = value;
            _selectedSubgrupo = _subgrupos.isNotEmpty ? _subgrupos[0] : null;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Seleccione una categoría';
        }
        return null;
      },
    );
  }

  Widget _buildSubgrupoSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedSubgrupo,
      decoration: const InputDecoration(
        labelText: "Tipo Específico",
        border: OutlineInputBorder(),
      ),
      items: _subgrupos
          .map((subgrupo) => DropdownMenuItem(
                value: subgrupo,
                child: Text(subgrupo),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedSubgrupo = value;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Seleccione un tipo específico';
        }
        return null;
      },
    );
  }

  Widget _buildNivelPeligroSelector() {
    if (!_mostrarNivelPeligroEnDialog) {
      return const SizedBox.shrink();
    }

    return DropdownButtonFormField<String>(
      value: _selectednivelPeligro,
      decoration: const InputDecoration(
        labelText: "Nivel de peligro",
        border: OutlineInputBorder(),
      ),
      items: ['Bajo', 'Medio', 'Alto']
          .map((nivel) => DropdownMenuItem(
                value: nivel,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getnivelPeligroColor(nivel),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(nivel),
                  ],
                ),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectednivelPeligro = value;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Nuevo Caso",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: SingleChildScrollView(
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
                                  Icon(widget.empresa.icon, color: Colors.blue[700], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Empresa: ${widget.empresa.nombre}',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.centroNombre != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.business_center, color: Color.fromARGB(255, 25, 118, 210), size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Centro: ${widget.centroNombre}',
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (widget.grupoNombre != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.group, color: Color.fromARGB(255, 25, 118, 210), size: 16),
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
                            labelText: "Nombre del caso",
                            border: OutlineInputBorder(),
                            hintText: "Ej: Fuga en tubería principal",
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El nombre es requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        _buildCategoriaSelector(),
                        const SizedBox(height: 16),
                        
                        _buildSubgrupoSelector(),
                        const SizedBox(height: 16),
                        
                        // Nivel de peligro condicional
                        _buildNivelPeligroSelector(),
                        if (_mostrarNivelPeligroEnDialog) const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text("Cancelar"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isFormValid && !_isLoading) ? _handleSave : null,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Crear Caso"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}