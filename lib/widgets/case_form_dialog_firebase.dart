// lib/widgets/case_form_dialog_firebase.dart
import 'package:flutter/material.dart';
import '../models/empresa_model.dart';
import '../services/firebase_service.dart';
import '../services/offline_case_service.dart';
import '../data/risk_data.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/interface_config_provider.dart';
import '../providers/connectivity_provider.dart';

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
  final _tipoPeligroLibreCtrl = TextEditingController();

  String _selectedCategoria = '';
  String? _selectedSubgrupo;
  String _selectednivelPeligro = 'Medio';
  bool _isLoading = false;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_configLoaded) {
      _configLoaded = true;
      final provider = Provider.of<InterfaceConfigProvider>(context, listen: false);
      final config = provider.currentConfig;
      final personalizadas = provider.categoriasPersonalizadas;
      final defaultNivel = config['nivelPeligroDefault'] as String? ?? 'Medio';
      final cats = _getCategoriasDisponibles(config, personalizadas);
      final primeraCat = cats.isNotEmpty ? cats[0] : 'Físico';
      final subs = _getSubgruposDisponibles(config, personalizadas, primeraCat);
      setState(() {
        _selectednivelPeligro = defaultNivel;
        _selectedCategoria = primeraCat;
        _selectedSubgrupo = subs.isNotEmpty ? subs[0] : null;
      });
    }
  }

  List<String> _getCategoriasDisponibles(
    Map<String, dynamic> config,
    List<Map<String, dynamic>> personalizadas,
  ) {
    final todosSubtipos = config['todosLosSubtipos'] as bool? ?? true;
    final todasEstandar = RiskData.getCategorias();
    final todasPersonalizadas =
        personalizadas.map((c) => c['categoria'] as String).toList();
    final todas = [...todasEstandar, ...todasPersonalizadas];
    if (todosSubtipos) return todas;
    final habilitadas =
        config['categoriasHabilitadas'] as Map<String, dynamic>? ?? {};
    final filtradas = todas.where((c) => habilitadas[c] == true).toList();
    return filtradas.isNotEmpty ? filtradas : todas;
  }

  List<String> _getSubgruposDisponibles(
    Map<String, dynamic> config,
    List<Map<String, dynamic>> personalizadas,
    String categoria,
  ) {
    final todosSubtipos = config['todosLosSubtipos'] as bool? ?? true;
    final todasLasCats = [...matrizPeligros, ...personalizadas];
    final base = RiskData.getSubgruposPorCategoriaFromAll(categoria, todasLasCats);
    if (todosSubtipos) return base;
    final habilitados =
        config['subtiposHabilitados'] as Map<String, dynamic>? ?? {};
    final personalizadosRaw =
        config['subtiposPersonalizados'] as Map<String, dynamic>? ?? {};
    final subtiposPersonalizadosEnCat =
        (personalizadosRaw[categoria] as List<dynamic>? ?? [])
            .cast<String>()
            .where((s) => habilitados[s] != false)
            .toList();
    final filtrados = base.where((s) => habilitados[s] == true).toList();
    final result = [...filtrados, ...subtiposPersonalizadosEnCat];
    return result.isNotEmpty ? result : base;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _tipoPeligroLibreCtrl.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final config = Provider.of<InterfaceConfigProvider>(context, listen: false).currentConfig;
    final modoLibre = config['modoTextoLibrePeligro'] as bool? ?? false;
    if (_nombreController.text.trim().isEmpty) return false;
    if (modoLibre) return _tipoPeligroLibreCtrl.text.trim().isNotEmpty;
    return _selectedSubgrupo != null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final grupoId = widget.grupoId ?? '';
    final centroId = widget.centroId ?? '';
    if (grupoId.isEmpty || centroId.isEmpty || widget.empresaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: datos incompletos (grupo=$grupoId, centro=$centroId, empresa=${widget.empresaId}). Cierra y vuelve a intentar.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final configProvider =
          Provider.of<InterfaceConfigProvider>(context, listen: false);
      final connectivityProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);

      final modoLibre =
          configProvider.currentConfig['modoTextoLibrePeligro'] as bool? ?? false;

      final todasLasCats = [
        ...matrizPeligros,
        ...configProvider.categoriasPersonalizadas,
      ];

      final casoData = {
        'empresaId': widget.empresaId,
        'empresaNombre': widget.empresa.nombre,
        'nombre': _nombreController.text.trim(),
        'cerrado': false,
        'centroId': centroId,
        'centroNombre': widget.centroNombre,
        'grupoId': grupoId,
        'grupoNombre': widget.grupoNombre,
        'creadoPor': authProvider.userData?['uid'],
      };

      if (modoLibre) {
        // Modo texto libre: no hay categoría del catálogo
        casoData['tipoPeligroLibre'] = _tipoPeligroLibreCtrl.text.trim();
        casoData['modoTextoLibrePeligro'] = true;
      } else {
        // Modo catálogo: categoría + subcategoría estándar
        casoData['tipoRiesgo'] = _selectedCategoria;
        casoData['subgrupoRiesgo'] = _selectedSubgrupo;
        casoData['numeroCategoria'] =
            RiskData.getNumeroCategoriaFromAll(_selectedCategoria, todasLasCats);
      }

      if (configProvider.isFeatureEnabled('mostrarNivelPeligroEnDialog')) {
        casoData['nivelPeligro'] = _selectednivelPeligro;
      }

      // ── OFFLINE: guardar en Hive ──────────────────────────────────────────
      if (!connectivityProvider.isOnline) {
        await OfflineCaseService.instance.saveCase(casoData);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Caso guardado localmente. Se sincronizará al recuperar conexión.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // ── ONLINE: guardar en Firestore ──────────────────────────────────────
      await FirebaseService.createCaso(
          grupoId, widget.empresaId, centroId, casoData);

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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getnivelPeligroColor(String nivel) {
    switch (nivel) {
      case 'Bajo':  return Colors.green;
      case 'Medio': return Colors.orange;
      case 'Alto':  return Colors.red[400]!;
      default:      return Colors.grey;
    }
  }

  /// Muestra un TextField libre o los dos dropdowns (categoría + subgrupo)
  /// dependiendo de la configuración del grupo.
  Widget _buildPeligroSection(
    bool modoLibre,
    List<String> categorias,
    List<String> subgrupos,
    List<Map<String, dynamic>> todasLasCats,
  ) {
    if (modoLibre) {
      return TextFormField(
        controller: _tipoPeligroLibreCtrl,
        textCapitalization: TextCapitalization.sentences,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Tipo de peligro *',
          hintText: 'Describe el tipo de peligro identificado...',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}), // refrescar _isFormValid
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? 'Describe el tipo de peligro' : null,
      );
    }
    return Column(
      children: [
        _buildCategoriaSelector(categorias, todasLasCats),
        const SizedBox(height: 16),
        _buildSubgrupoSelector(subgrupos),
      ],
    );
  }

  Widget _buildCategoriaSelector(
      List<String> categorias, List<Map<String, dynamic>> todasLasCats) {
    return DropdownButtonFormField<String>(
      initialValue: categorias.contains(_selectedCategoria)
          ? _selectedCategoria
          : (categorias.isNotEmpty ? categorias[0] : null),
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Categoría de Peligro",
        border: OutlineInputBorder(),
      ),
      items: categorias
          .map((categoria) => DropdownMenuItem(
                value: categoria,
                child: Row(
                  children: [
                    Icon(
                      RiskData.getIconPorCategoriaFromAll(categoria, todasLasCats),
                      color: RiskData.getColorPorCategoriaFromAll(categoria, todasLasCats),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(categoria, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          final config =
              Provider.of<InterfaceConfigProvider>(context, listen: false)
                  .currentConfig;
          final personalizadas =
              Provider.of<InterfaceConfigProvider>(context, listen: false)
                  .categoriasPersonalizadas;
          final subs = _getSubgruposDisponibles(config, personalizadas, value);
          setState(() {
            _selectedCategoria = value;
            _selectedSubgrupo = subs.isNotEmpty ? subs[0] : null;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) return 'Seleccione una categoría';
        return null;
      },
    );
  }

  Widget _buildSubgrupoSelector(List<String> subgrupos) {
    return DropdownButtonFormField<String>(
      initialValue: subgrupos.contains(_selectedSubgrupo) ? _selectedSubgrupo : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Tipo específico",
        border: OutlineInputBorder(),
      ),
      items: subgrupos
          .map((subgrupo) => DropdownMenuItem(
                value: subgrupo,
                child: Text(subgrupo, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _selectedSubgrupo = value);
      },
      validator: (value) {
        if (value == null || value.isEmpty) return 'Seleccione un tipo específico';
        return null;
      },
    );
  }

  Widget _buildNivelPeligroSelector(bool mostrar) {
    if (!mostrar) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      initialValue: _selectednivelPeligro,
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
        if (value != null) setState(() => _selectednivelPeligro = value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<InterfaceConfigProvider>(context);
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final config = configProvider.currentConfig;
    final personalizadas = configProvider.categoriasPersonalizadas;
    final todasLasCats = [...matrizPeligros, ...personalizadas];

    final categoriasDisponibles = _getCategoriasDisponibles(config, personalizadas);
    final subgruposDisponibles = _getSubgruposDisponibles(
      config,
      personalizadas,
      _selectedCategoria.isNotEmpty
          ? _selectedCategoria
          : (categoriasDisponibles.isNotEmpty ? categoriasDisponibles[0] : 'Físico'),
    );
    final mostrarNivelPeligro = config['mostrarNivelPeligroEnDialog'] as bool? ?? false;
    final modoTextoLibrePeligro = config['modoTextoLibrePeligro'] as bool? ?? false;
    final isOffline = !connectivityProvider.isOnline;

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
              // Título
              Row(
                children: [
                  Text(
                    "Nuevo Caso",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (isOffline) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off,
                              size: 12, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Sin conexión',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Banner offline
                        if (isOffline)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'El caso se guardará localmente y se sincronizará al recuperar conexión.',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ),

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
                                  Icon(widget.empresa.icon,
                                      color: Colors.blue[700], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Empresa: ${widget.empresa.nombre}',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                              if (widget.centroNombre != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.business_center,
                                        color: Color.fromARGB(255, 25, 118, 210),
                                        size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Centro: ${widget.centroNombre}',
                                      style: TextStyle(
                                          color: Colors.blue[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                              if (widget.grupoNombre != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.group,
                                        color: Color.fromARGB(255, 25, 118, 210),
                                        size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Grupo: ${widget.grupoNombre}',
                                      style: TextStyle(
                                          color: Colors.blue[600], fontSize: 12),
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

                        _buildPeligroSection(
                          modoTextoLibrePeligro,
                          categoriasDisponibles,
                          subgruposDisponibles,
                          todasLasCats,
                        ),
                        const SizedBox(height: 16),

                        _buildNivelPeligroSelector(mostrarNivelPeligro),
                        if (mostrarNivelPeligro) const SizedBox(height: 16),
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
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: const Text("Cancelar"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          (_isFormValid && !_isLoading) ? _handleSave : null,
                      style: isOffline
                          ? ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            )
                          : null,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isOffline ? "Guardar offline" : "Crear Caso"),
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