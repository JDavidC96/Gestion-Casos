// lib/screens/case_list_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/case_model.dart';
import '../models/empresa_model.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../providers/interface_config_provider.dart';
import '../widgets/case_form_dialog_firebase.dart';
import '../widgets/case_card.dart';
import '../widgets/empty_cases_state.dart';
import '../widgets/closed_cases_header.dart';
import '../widgets/closed_cases_button.dart';
import '../widgets/configurable_feature.dart';
import '../services/report_service.dart';
import '../services/offline_case_service.dart';
import '../services/sync_service.dart';
import '../providers/connectivity_provider.dart';
import 'dart:async';

class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  // QUITAR 'late' y inicializar con valores por defecto
  Empresa _empresa = Empresa(
    id: "empresa_default",
    nombre: "Empresa X",
    nit: "",
    icon: Icons.business,
  );
  String _grupoId   = "";
  String _empresaId = "empresa_default";
  String? _centroId;
  String? _centroNombre;
  IconData? _empresaIcon;
  bool _isInitialized = false;

  // Suscripciones a streams offline — se cancelan en dispose
  StreamSubscription? _syncSub;
  StreamSubscription? _offlineSub;

  @override
  void initState() {
    super.initState();
    _syncSub = SyncService.instance.onSyncDone.listen((_) {
      if (mounted) setState(() {});
    });
    _offlineSub = OfflineCaseService.instance.casesStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _offlineSub?.cancel();
    super.dispose();
  }

  /// Lee directamente de Hive en cada build — siempre reactivo.
  List<Map<String, dynamic>> get _casosOffline {
    if (_empresaId == 'empresa_default' || _empresaId.isEmpty) return [];
    return OfflineCaseService.instance.getPending().where((c) {
      final matchEmpresa = c['empresaId'] == _empresaId;
      final matchCentro = _centroId == null || c['centroId'] == _centroId;
      return matchEmpresa && matchCentro;
    }).toList();
  }

  // didChangeDependencies se ejecuta antes del primer build y tiene acceso
  // a ModalRoute. Así _grupoId y _empresaId están listos antes de que el
  // StreamBuilder intente construir la query de Firestore, evitando el
  // ArgumentError por path vacío.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _initializeEmpresaFromArguments();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInterfaceConfig();
      });
    }
  }

  void _initializeEmpresaFromArguments() {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    
    if (args != null) {
      setState(() {
        _grupoId   = args["grupoId"] ?? "";
        _empresaId = args["empresaId"] ?? "empresa_default";
        _empresa = Empresa(
          id: _empresaId,
          nombre: args["empresaNombre"] ?? "Empresa X",
          nit: args["nit"] ?? "",
          icon: args["icon"] ?? Icons.business,
        );
        _centroId = args["centroId"];
        _centroNombre = args["centroNombre"];
        _empresaIcon = args["icon"];
      });
    }
    // Si no hay argumentos, ya tenemos los valores por defecto
  }

  // Método simplificado: solo cargar configuración sin setState
  void _loadInterfaceConfig() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
    
    if (authProvider.grupoId != null) {
      if (authProvider.grupoId != null) configProvider.loadConfig(authProvider.grupoId!);
    }
  }

  // Método para obtener el nivel de peligro actualizado
  String _getNivelPeligroActualizado(Map<String, dynamic> data) {
    final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>?;
    if (estadoAbierto != null && estadoAbierto['nivelPeligro'] != null) {
      return estadoAbierto['nivelPeligro'] as String;
    }
    return data['nivelPeligro'] ?? '';
  }

  // Método para verificar permisos de creación de casos
  bool _puedeCrearCasos(AuthProvider authProvider) {
    // Admin puede crear casos en su grupo, super_admin en todos, inspectores según configuración
    return authProvider.isAdmin || 
           authProvider.isSuperAdmin || 
           (authProvider.isAnyInspector && 
            authProvider.puedeAccederAEmpresa(_empresaId));
  }

  void _openAddCaseModal() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Verificar permisos actualizados
    if (!_puedeCrearCasos(authProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para crear casos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CaseFormDialogFirebase(
        empresa: _empresa,
        empresaId: _empresaId,
        centroId: _centroId,
        centroNombre: _centroNombre,
        grupoId: authProvider.grupoId ?? _grupoId,
        grupoNombre: authProvider.grupoNombre,
      ),
    );
  }

  void _navegarACasosCerrados(List<Case> casosCerrados) {
    Navigator.pushNamed(
      context,
      '/closedCases',
      arguments: {
        "grupoId": _grupoId,
        "empresa": _empresa,
        "empresaId": _empresaId,
        "centroId": _centroId,
        "centroNombre": _centroNombre,
        "casosCerrados": casosCerrados,
      },
    );
  }

  // ─── Permisos de edición / eliminación ────────────────────────────────────

  /// Admin y super_admin pueden editar cualquier caso de su grupo.
  /// Inspector solo puede editar los suyos (creadoPor == su uid).
  bool _puedeEditarCaso(AuthProvider auth, Map<String, dynamic> data) {
    if (auth.isSuperAdmin || auth.isAdmin) return true;
    return auth.isAnyInspector &&
        (data['creadoPor'] ?? '') == (auth.userData?['uid'] ?? '__none__');
  }

  /// Admin y super_admin pueden eliminar cualquier caso.
  /// Inspector solo puede eliminar los suyos.
  bool _puedeEliminarCaso(AuthProvider auth, Map<String, dynamic> data) {
    if (auth.isSuperAdmin || auth.isAdmin) return true;
    return auth.isAnyInspector &&
        (data['creadoPor'] ?? '') == (auth.userData?['uid'] ?? '__none__');
  }

  // ─── Editar caso ────────────────────────────────────────────────────────

  void _editarCaso(String casoId, Map<String, dynamic> data) {
    final nombreCtrl = TextEditingController(text: data['nombre'] ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('Editar caso'),
          ],
        ),
        content: TextField(
          controller: nombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del caso',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevoNombre = nombreCtrl.text.trim();
              if (nuevoNombre.isEmpty) return;
              Navigator.pop(context);
              try {
                await FirebaseService.updateCaso(
                  _grupoId, _empresaId, _centroId ?? '', casoId,
                  {'nombre': nuevoNombre},
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Caso actualizado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al actualizar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Eliminar caso ──────────────────────────────────────────────────────

  Future<void> _confirmarEliminarCaso(
      String casoId, String nombreCaso) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar caso'),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar el caso\n"$nombreCaso"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await FirebaseService.deleteCaso(
            _grupoId, _empresaId, _centroId ?? '', casoId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Caso eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _navegarADetalleCaso(String casoId, Case caso) {
    Navigator.pushNamed(
      context,
      '/caseDetail',
      arguments: {
        "grupoId":   _grupoId,
        "empresaId": _empresaId,
        "centroId":  _centroId,
        "casoId":    casoId,
        "caso":      caso,
      },
    );
  }

  String _getAppBarTitle() {
    if (_centroNombre != null) {
      return 'Casos - $_centroNombre';
    }
    return 'Casos - ${_empresa.nombre}';
  }

  String _getSubtitle() {
    if (_centroNombre != null) {
      return 'Centro: $_centroNombre';
    }
    return 'Empresa: ${_empresa.nombre}';
  }

  // Método para obtener el color del nivel de riesgo según la configuración
  Color? _getNivelRiesgoColor(Case caso, InterfaceConfigProvider configProvider) {
    if (!configProvider.isFeatureEnabled('mostrarNivelRiesgo')) return null;
    
    switch (caso.nivelPeligro) {
      case 'Bajo':
        return Colors.green;
      case 'Medio':
        return Colors.orange;
      case 'Alto':
        return Colors.red[400];
      default:
        return Colors.grey;
    }
  }

    // En case_list_screen.dart, dentro de _CaseListScreenState

void _mostrarDialogoReporteDiario() {
  // Variables que mantendrán el estado fuera del StatefulBuilder
  DateTime fechaSeleccionada = DateTime.now();
  String? supervisorSeleccionado;
  bool incluirCerrados = true;
  bool isLoading = false;
  
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Generar Reporte Diario'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selector de fecha
                  ListTile(
                    title: const Text('Fecha'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(fechaSeleccionada)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: fechaSeleccionada, // Usar la fecha seleccionada actual
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null && picked != fechaSeleccionada) {
                        // Actualizar la variable y el diálogo
                        fechaSeleccionada = picked;
                        setDialogState(() {}); // Forzar rebuild del diálogo
                      }
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Selector de supervisor
                  FutureBuilder<List<String>>(
                    future: _obtenerSupervisores(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasData) {
                        final supervisores = snapshot.data!;
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Supervisor (opcional)',
                            border: OutlineInputBorder(),
                          ),
                          value: supervisorSeleccionado,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Todos los supervisores'),
                            ),
                            ...supervisores.map((s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            )),
                          ],
                          onChanged: (value) {
                            supervisorSeleccionado = value;
                            setDialogState(() {}); // Forzar rebuild
                          },
                        );
                      }
                      
                      return const Text('Error cargando supervisores');
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Checkbox para incluir cerrados
                  CheckboxListTile(
                    title: const Text('Incluir casos cerrados'),
                    value: incluirCerrados,
                    onChanged: (value) {
                      incluirCerrados = value ?? true;
                      setDialogState(() {}); // Forzar rebuild
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              // Helper local para obtener los docs del reporte diario
              ...(() {
                Future<void> ejecutar({required bool compartir}) async {
                  setDialogState(() => isLoading = true);
                  try {
                    final casosDocs = await FirebaseService.getCasosDocsParaReporte(
                      _grupoId, _empresaId);
                    Navigator.pop(context);
                    if (compartir) {
                      await ReportService.compartirReporteCasosPDF(
                        casos: casosDocs,
                        fecha: fechaSeleccionada,
                        supervisor: supervisorSeleccionado,
                        incluirCerrados: incluirCerrados,
                        empresaNombre: _empresa.nombre,
                        centroNombre: _centroNombre,
                        grupoId: _grupoId,
                      );
                    } else {
                      await ReportService.generarReporteCasosPDF(
                        casos: casosDocs,
                        fecha: fechaSeleccionada,
                        supervisor: supervisorSeleccionado,
                        incluirCerrados: incluirCerrados,
                        empresaNombre: _empresa.nombre,
                        centroNombre: _centroNombre,
                        grupoId: _grupoId,
                      );
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(compartir
                              ? '✅ PDF listo para compartir'
                              : '✅ Reporte generado exitosamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }

                return [
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : () => ejecutar(compartir: false),
                    icon: isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Ver PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : () => ejecutar(compartir: true),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Compartir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ];
              })(),
            ],
          );
        },
      );
    },
  );
}

  // NUEVO MÉTODO 2 - Obtener supervisores
  Future<List<String>> _obtenerSupervisores() async {
    try {
      final casos = await FirebaseService.getCasosPorEmpresa(_grupoId, _empresaId);
      final supervisores = <String>{};
      for (final data in casos) {
        final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>?;
        final nombre = estadoAbierto?['usuarioNombre'] ?? data['usuarioNombre'];
        if (nombre != null && (nombre as String).isNotEmpty) {
          supervisores.add(nombre);
        }
      }
      return supervisores.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  // Método para determinar si mostrar el nivel de riesgo
  bool _debeMostrarNivelRiesgo(Case caso, InterfaceConfigProvider configProvider) {
    return configProvider.isFeatureEnabled('mostrarNivelRiesgo') && 
           caso.nivelPeligro.isNotEmpty && 
           caso.nivelPeligro != 'No aplica';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final configProvider = Provider.of<InterfaceConfigProvider>(context);
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);

    // Mientras los argumentos no estén listos, mostrar loading en lugar de
    // lanzar un query de Firestore con path vacío.
    if (!_isInitialized || _grupoId.isEmpty || _empresaId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getAppBarTitle()),
            Text(
              _getSubtitle(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: !connectivityProvider.isOnline
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Container(
                  width: double.infinity,
                  color: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      const Text(
                        'Sin conexión — mostrando datos locales',
                        style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      if (connectivityProvider.hasPending) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${connectivityProvider.pendingCount} pendiente${connectivityProvider.pendingCount != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : connectivityProvider.hasPending
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(28),
                    child: Container(
                      width: double.infinity,
                      color: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sincronizando ${connectivityProvider.pendingCount} caso${connectivityProvider.pendingCount != 1 ? 's' : ''}...',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
        actions: [
          IconButton(onPressed: _mostrarDialogoReporteDiario,
           icon: const Icon(Icons.picture_as_pdf),
           tooltip: 'Generar Reporte Diario',
           ),

          // Información del grupo
          if (authProvider.grupoNombre != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Text(
                  authProvider.grupoNombre!,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
          // Botón de casos cerrados - configurable
          ConfigurableFeature(
            feature: 'mostrarCasosCerrados',
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseService.getCasosPorEmpresaStream(_grupoId, _empresaId, _centroId ?? ''),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                
                final casosCerrados = snapshot.data!.docs
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['cerrado'] == true;
                    })
                    .length;

                if (casosCerrados == 0) return const SizedBox.shrink();

                return ClosedCasesButton(
                  casosCerradosCount: casosCerrados,
                  onPressed: () {
                    final casosCerradosList = snapshot.data!.docs
                        .where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['cerrado'] == true;
                        })
                        .map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Case(
                            id: doc.id,
                            empresaId: data['empresaId'] ?? '',
                            empresaNombre: data['empresaNombre'] ?? '',
                            nombre: data['nombre'] ?? '',
                            tipoRiesgo: data['tipoRiesgo'] ?? '',
                            descripcionRiesgo: data['descripcionRiesgo'] ?? '',
                            nivelPeligro: _getNivelPeligroActualizado(data),
                            fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
                            fechaCierre: (data['fechaCierre'] as Timestamp?)?.toDate(),
                            cerrado: data['cerrado'] ?? false,
                          );
                        })
                        .toList();
                    
                    _navegarACasosCerrados(casosCerradosList);
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: connectivityProvider.isOnline
              ? FirebaseService.getCasosPorEmpresaStream(_grupoId, _empresaId, _centroId ?? '')
              : const Stream.empty(),
          builder: (context, snapshot) {

            // ── Guardar caché cada vez que llegan datos frescos de Firestore ─
            if (connectivityProvider.isOnline &&
                snapshot.hasData &&
                snapshot.connectionState == ConnectionState.active) {
              final cacheKey = '${_grupoId}_${_empresaId}_${_centroId ?? ""}';
              final casosParaCache = snapshot.data!.docs
                  .where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return authProvider.puedeAccederRecurso(data['grupoId']) &&
                        data['cerrado'] != true;
                  })
                  .map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {...data, 'id': doc.id};
                  })
                  .toList();
              OfflineCaseService.instance
                  .saveFirestoreCache(cacheKey, casosParaCache);
            }

            // ── Sin red: offline pendientes + caché Firestore ─────────────
            if (!connectivityProvider.isOnline) {
              final cacheKey = '${_grupoId}_${_empresaId}_${_centroId ?? ""}';
              final cachedCasos =
                  OfflineCaseService.instance.getFirestoreCache(cacheKey);

              final totalItems = _casosOffline.length + cachedCasos.length;

              if (totalItems == 0) {
                return EmptyCasesState(
                  empresaIcon: _empresaIcon ?? Icons.business,
                  empresaNombre: _empresa.nombre,
                  centroNombre: _centroNombre,
                  casosCerradosCount: 0,
                  onAddCase: _openAddCaseModal,
                  onViewClosedCases: () => _navegarACasosCerrados([]),
                  puedeAgregar: _puedeCrearCasos(authProvider),
                );
              }
              return ListView.builder(
                itemCount: totalItems,
                itemBuilder: (context, index) {
                  // Primero los offline pendientes
                  if (index < _casosOffline.length) {
                    return _buildOfflineCaseCard(_casosOffline[index]);
                  }
                  // Luego los cacheados de Firestore (solo lectura)
                  final cachedIndex = index - _casosOffline.length;
                  final data = cachedCasos[cachedIndex];
                  final casoId = data['id'] as String? ?? '';
                  final caso = Case(
                    id: casoId,
                    empresaId: data['empresaId'] ?? '',
                    empresaNombre: data['empresaNombre'] ?? '',
                    nombre: data['nombre'] ?? '',
                    tipoRiesgo: data['tipoRiesgo'] ?? '',
                    descripcionRiesgo: data['descripcionRiesgo'] ?? '',
                    nivelPeligro: _getNivelPeligroActualizado(data),
                    fechaCreacion: (data['fechaCreacion'] is Timestamp)
                        ? (data['fechaCreacion'] as Timestamp).toDate()
                        : DateTime.now(),
                    cerrado: false,
                  );
                  return CaseCard(
                    caso: caso,
                    onTap: () => _navegarADetalleCaso(casoId, caso),
                    mostrarNivelRiesgo:
                        _debeMostrarNivelRiesgo(caso, configProvider),
                    nivelRiesgoColor:
                        _getNivelRiesgoColor(caso, configProvider),
                    mostrarMenu: false,
                  );
                },
              );
            }

            // ── Con red: errores y loading ────────────────────────────────
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Volver'),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('No hay datos', style: TextStyle(color: Colors.white)));
            }

            // Filtrar casos por grupo
            final casosFiltrados = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return authProvider.puedeAccederRecurso(data['grupoId']);
            }).toList();

            // Separar casos abiertos y cerrados
            final casosAbiertos = <QueryDocumentSnapshot>[];
            final casosCerrados = <Case>[];

            for (var doc in casosFiltrados) {
              final data = doc.data() as Map<String, dynamic>;
              final cerrado = data['cerrado'] ?? false;

              if (!cerrado) {
                casosAbiertos.add(doc);
              } else {
                casosCerrados.add(Case(
                  id: doc.id,
                  empresaId: data['empresaId'] ?? '',
                  empresaNombre: data['empresaNombre'] ?? '',
                  nombre: data['nombre'] ?? '',
                  tipoRiesgo: data['tipoRiesgo'] ?? '',
                  descripcionRiesgo: data['descripcionRiesgo'] ?? '',
                  nivelPeligro: _getNivelPeligroActualizado(data),
                  fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  fechaCierre: (data['fechaCierre'] as Timestamp?)?.toDate(),
                  cerrado: true,
                ));
              }
            }

            final totalItems = _casosOffline.length + casosAbiertos.length;

            if (totalItems == 0) {
              return EmptyCasesState(
                empresaIcon: _empresaIcon ?? Icons.business,
                empresaNombre: _empresa.nombre,
                centroNombre: _centroNombre,
                casosCerradosCount: casosCerrados.length,
                onAddCase: _openAddCaseModal,
                onViewClosedCases: () => _navegarACasosCerrados(casosCerrados),
                puedeAgregar: _puedeCrearCasos(authProvider),
              );
            }

            return Column(
              children: [
                // Header de casos cerrados - configurable
                ConfigurableFeature(
                  feature: 'mostrarCasosCerrados',
                  child: casosCerrados.isNotEmpty
                      ? ClosedCasesHeader(
                          casosCerradosCount: casosCerrados.length,
                          onViewClosedCases: () => _navegarACasosCerrados(casosCerrados),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: totalItems,
                    itemBuilder: (context, index) {
                      // Primero los casos offline (al tope de la lista)
                      if (index < _casosOffline.length) {
                        return _buildOfflineCaseCard(_casosOffline[index]);
                      }
                      // Luego los de Firestore
                      final firestoreIndex = index - _casosOffline.length;
                      final doc = casosAbiertos[firestoreIndex];
                      final data = doc.data() as Map<String, dynamic>;
                      final casoId = doc.id;

                      final caso = Case(
                        id: casoId,
                        empresaId: data['empresaId'] ?? '',
                        empresaNombre: data['empresaNombre'] ?? '',
                        nombre: data['nombre'] ?? '',
                        tipoRiesgo: data['tipoRiesgo'] ?? '',
                        descripcionRiesgo: data['descripcionRiesgo'] ?? '',
                        nivelPeligro: _getNivelPeligroActualizado(data),
                        fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
                        cerrado: false,
                      );

                      final puedeEditar  = _puedeEditarCaso(authProvider, data);
                      final puedeEliminar = _puedeEliminarCaso(authProvider, data);

                      return CaseCard(
                        caso: caso,
                        onTap: () => _navegarADetalleCaso(casoId, caso),
                        mostrarNivelRiesgo: _debeMostrarNivelRiesgo(caso, configProvider),
                        nivelRiesgoColor: _getNivelRiesgoColor(caso, configProvider),
                        mostrarMenu: puedeEditar || puedeEliminar,
                        onEdit:   puedeEditar   ? () => _editarCaso(casoId, data)             : null,
                        onDelete: puedeEliminar ? () => _confirmarEliminarCaso(casoId, caso.nombre) : null,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: 
          // Mostrar FAB si tiene permisos
          _puedeCrearCasos(authProvider)
            ? FloatingActionButton(
                heroTag: 'fab_case_list',
                onPressed: _openAddCaseModal,
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                child: const Icon(FontAwesomeIcons.plus),
              )
            : null,
    );
  }

  // ─── Tarjeta para casos offline ─────────────────────────────────────────

  Widget _buildOfflineCaseCard(Map<String, dynamic> caso) {
    final offlineId = caso['offlineId'] as String;
    final nombre = caso['nombre'] as String? ?? 'Sin nombre';
    final tipoRiesgo = caso['tipoRiesgo'] as String? ?? '';
    final creadoAt = caso['creadoAt'] as String?;
    final fecha = creadoAt != null
        ? DateTime.tryParse(creadoAt) ?? DateTime.now()
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Icon(Icons.cloud_off, color: Colors.orange.shade600, size: 22),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tipoRiesgo.isNotEmpty)
              Text(tipoRiesgo, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Sin sincronizar',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${fecha.day}/${fecha.month}/${fecha.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _navegarADetalleCasoOffline(offlineId, caso),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          tooltip: 'Descartar caso offline',
          onPressed: () => _confirmarDescartarOffline(offlineId, nombre),
        ),
      ),
    );
  }

  void _navegarADetalleCasoOffline(String offlineId, Map<String, dynamic> caso) {
    Navigator.pushNamed(
      context,
      '/caseDetail',
      arguments: {
        "grupoId":   caso['grupoId'] ?? _grupoId,
        "empresaId": caso['empresaId'] ?? _empresaId,
        "centroId":  caso['centroId'] ?? _centroId,
        "casoId":    offlineId,
        "caso": Case(
          id: offlineId,
          empresaId: caso['empresaId'] ?? _empresaId,
          empresaNombre: caso['empresaNombre'] ?? _empresa.nombre,
          nombre: caso['nombre'] ?? '',
          tipoRiesgo: caso['tipoRiesgo'] ?? '',
          descripcionRiesgo: '',
          nivelPeligro: caso['nivelPeligro'] ?? '',
          fechaCreacion: caso['creadoAt'] != null
              ? DateTime.tryParse(caso['creadoAt'] as String) ?? DateTime.now()
              : DateTime.now(),
          cerrado: false,
        ),
        "esOffline": true,
      },
    );
  }

  Future<void> _confirmarDescartarOffline(String offlineId, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Descartar caso'),
          ],
        ),
        content: Text(
          '¿Descartar el caso "$nombre"?\n\nSe eliminará localmente y no se subirá a Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Descartar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await OfflineCaseService.instance.deleteCase(offlineId);
    }
  }
}