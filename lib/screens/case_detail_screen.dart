// lib/screens/case_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'report_screen.dart';
import '../controllers/case_detail_controller.dart';
import '../providers/auth_provider.dart';
import '../providers/interface_config_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/offline_case_service.dart';
import '../services/sync_service.dart';
import 'dart:async';
import '../widgets/case_state_card_firebase.dart';
import '../widgets/closed_state_card_firebase.dart';
import '../widgets/configurable_feature.dart';
import '../theme/app_colors.dart';

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  late final CaseDetailController _ctrl;
  bool _esOffline = false;   // true si el caso aún no está en Firestore
  StreamSubscription? _syncSub;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = CaseDetailController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAll();
    });
    // Cuando SyncService termina, verificar si este caso fue sincronizado
    _syncSub = SyncService.instance.onSyncDone.listen((_) {
      if (_esOffline && mounted) _checkIfSynced();
    });
  }

  /// Verifica si el caso offline ya fue sincronizado y tiene ID real en Firestore.
  /// Si es así, actualiza el controller sin borrar lo que el usuario escribió.
  void _checkIfSynced() {
    final offlineId = _ctrl.casoId;
    if (offlineId == null || !offlineId.startsWith('offline_')) return;

    // Buscar si el caso fue marcado como sincronizado (firestoreId disponible)
    final syncedCase = OfflineCaseService.instance.getCase(offlineId);
    if (syncedCase == null) {
      // El caso fue eliminado de Hive — ya está en Firestore
      // No podemos recuperar el firestoreId en este punto, pero al menos
      // desbloqueamos la pantalla para que el usuario sepa que puede navegar
      return;
    }
    final firestoreId = syncedCase['firestoreId'] as String?;
    if (firestoreId != null) {
      setState(() => _esOffline = false);
      _ctrl.onCaseSynced(firestoreId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.cloud_done, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Caso sincronizado — ya puedes guardar'),
          ]),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _initAll() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);

    _ctrl.initFromArgs(args);
    _ctrl.setUsuario(authProvider.userData);
    _esOffline = args?['esOffline'] == true;

    // Registrar listener antes de cargar para que la UI reaccione inmediatamente
    _ctrl.addListener(_onControllerChanged);

    // Cargar config de interfaz (no bloquea)
    if (authProvider.grupoId != null) {
      configProvider.loadConfig(authProvider.grupoId!);
    }

    // PRIORIDAD 1: Cargar datos del caso
    try {
      if (_esOffline) {
        // Caso offline: leer desde Hive
        final casoId = _ctrl.casoId ?? '';
        final localData = OfflineCaseService.instance.getCase(casoId);
        if (localData != null) {
          _ctrl.loadFromLocalData(localData);
        }
      } else {
        await _ctrl.loadFromFirestore();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando caso: $e')),
        );
      }
    }

    if (mounted) setState(() {});

    // PRIORIDAD 2: Cargar firmas en segundo plano (no bloquean la UI)
    _ctrl.loadFirmaInspectorFromProfile(authProvider.userData);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _ctrl.removeListener(_onControllerChanged);
    _ctrl.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // ─── Permisos ────────────────────────────────────────────────────────────

  bool _puedeCerrarCasos() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.isAdmin || auth.isSuperAdmin || auth.isAnyInspector;
  }

  // ─── Callbacks deshabilitados ────────────────────────────────────────────

  void _tomarFotoDeshabilitada() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La función de fotos está deshabilitada')),
    );
  }

  void _nivelPeligroDeshabilitado(String? value) {}

  // ─── Acciones que delegan al controller ──────────────────────────────────

  Future<void> _onTomarFoto({required bool esEstadoAbierto}) async {
    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
    if (!configProvider.isFeatureEnabled('habilitarFotos')) {
      _tomarFotoDeshabilitada();
      return;
    }

    final error = await _ctrl.tomarFoto(esEstadoAbierto: esEstadoAbierto);
    if (!mounted) return;

    if (error != null) {
      // ❌ Fallo — la foto local ya fue eliminada por el controller
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
      );
    } else if (_ctrl.fotoAbiertoUrl != null || _ctrl.fotoCerradoUrl != null) {
      // ✅ Éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto subida exitosamente'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _guardarEstadoAbierto() async {
    // Bloquear si el caso aún no está sincronizado con Firestore
    if (_esOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Disponible al sincronizar. Conecta a internet para guardar.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!_puedeCerrarCasos()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permisos para guardar estados de casos'), backgroundColor: Colors.red),
      );
      return;
    }

    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
    final error = await _ctrl.guardarEstadoAbierto(
      mostrarNivelPeligro: configProvider.isFeatureEnabled('mostrarNivelPeligroEnDetalle'),
      habilitarFotos: configProvider.isFeatureEnabled('habilitarFotos'),
    );

    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estado abierto guardado exitosamente'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _guardarEstadoCerrado() async {
    if (_esOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Disponible al sincronizar. Conecta a internet para cerrar el caso.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!_puedeCerrarCasos()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permisos para cerrar casos'), backgroundColor: Colors.red),
      );
      return;
    }

    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
    final error = await _ctrl.guardarEstadoCerrado(
      habilitarFotos: configProvider.isFeatureEnabled('habilitarFotos'),
    );

    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caso cerrado exitosamente'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final empresaNombre = _ctrl.casoData?['empresaNombre'] ?? 'Sin empresa';
    final nombre = _ctrl.casoData?['nombre'] ?? 'Caso sin descripción';
    final configProvider = Provider.of<InterfaceConfigProvider>(context);
    final mostrarNivelPeligro = configProvider.isFeatureEnabled('mostrarNivelPeligroEnDetalle');
    final habilitarFotos = configProvider.isFeatureEnabled('habilitarFotos');

    final onTomarFotoAbierto = habilitarFotos
        ? () => _onTomarFoto(esEstadoAbierto: true)
        : _tomarFotoDeshabilitada;
    final onTomarFotoCerrado = habilitarFotos
        ? () => _onTomarFoto(esEstadoAbierto: false)
        : _tomarFotoDeshabilitada;
    final onNivelPeligroChanged = mostrarNivelPeligro
        ? (String? value) {
            if (value != null) {
              setState(() => _ctrl.nivelPeligro = value);
              _ctrl.scheduleDraftSave();
            }
          }
        : _nivelPeligroDeshabilitado;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: AppColors.warmOrangeStart,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            bottom: _esOffline
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(28),
                    child: Container(
                      width: double.infinity,
                      color: Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 12),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_off, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Caso offline — guarda y cierre disponibles al sincronizar',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
          body: _ctrl.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  decoration: const BoxDecoration(gradient: AppColors.gradientWarmOrange),
                  child: Column(
                    children: [
                      _buildHeader(empresaNombre, nombre),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              CaseStateCardFirebase(
                                titulo: 'Estado Abierto',
                                subtitulo: 'Complete la información inicial del caso',
                                descripcionHallazgo: _ctrl.descripcionHallazgo,
                                nivelPeligro: _ctrl.nivelPeligro,
                                recomendacionesControl: _ctrl.recomendacionesControl,
                                fotoPath: _ctrl.fotoAbiertoPath,
                                fotoUrl: _ctrl.fotoAbiertoUrl,
                                firma: _ctrl.firmaAbierto,
                                firmaUrl: _ctrl.firmaAbiertoUrl,
                                bloqueado: _ctrl.estadoAbiertoGuardado,
                                usuarioNombre: _ctrl.responsableAbiertoNombre,
                                ubicacionController: _ctrl.ubicacionTextoCtrl,
                                habilitarFotos: habilitarFotos,
                                habilitarFirmas: configProvider.isFeatureEnabled('habilitarFirmas'),
                                mostrarNivelPeligro: mostrarNivelPeligro,
                                onUbicacionChanged: (_) => _ctrl.scheduleDraftSave(),
                                onDescripcionChanged: (value) {
                                  setState(() => _ctrl.descripcionHallazgo = value);
                                  _ctrl.scheduleDraftSave();
                                },
                                onnivelPeligroChanged: onNivelPeligroChanged,
                                onRecomendacionesChanged: (value) {
                                  setState(() => _ctrl.recomendacionesControl = value);
                                  _ctrl.scheduleDraftSave();
                                },
                                onTomarFoto: onTomarFotoAbierto,
                                onGuardar: _guardarEstadoAbierto,
                                tomandoFoto: _ctrl.tomandoFoto,
                                subiendoFoto: _ctrl.subiendoFotoAbierto,
                                firmaCliente: _ctrl.firmaClienteAbierto,
                                nombreCliente: _ctrl.nombreClienteAbierto,
                                onFirmaClienteChanged: (bytes) => _ctrl.setFirmaCliente(esAbierto: true, bytes: bytes),
                                onNombreClienteChanged: (value) {
                                  setState(() => _ctrl.nombreClienteAbierto = value);
                                  _ctrl.scheduleDraftSave();
                                },
                              ),
                              ConfigurableFeature(
                                feature: 'habilitarReportes',
                                child: _ctrl.estadoAbiertoGuardado
                                    ? _buildGenerarReporteButton()
                                    : const SizedBox.shrink(),
                              ),
                              if (_ctrl.estadoAbiertoGuardado && !_ctrl.casoCerrado)
                                _buildCerrarCasoButton(),
                              if (_ctrl.casoCerrado)
                                ClosedStateCardFirebase(
                                  titulo: 'Estado Cerrado',
                                  subtitulo: 'Complete la información de cierre del caso',
                                  descripcionSolucion: _ctrl.descripcionSolucion,
                                  fotoPath: _ctrl.fotoCerradoPath,
                                  fotoUrl: _ctrl.fotoCerradoUrl,
                                  firma: _ctrl.firmaCerrado,
                                  firmaUrl: _ctrl.firmaCerradoUrl,
                                  bloqueado: _ctrl.estadoCerradoGuardado,
                                  usuarioNombre: _ctrl.responsableCerradoNombre,
                                  habilitarFotos: habilitarFotos,
                                  habilitarFirmas: configProvider.isFeatureEnabled('habilitarFirmas'),
                                  onDescripcionSolucionChanged: (value) {
                                    setState(() => _ctrl.descripcionSolucion = value);
                                    _ctrl.scheduleDraftSave();
                                  },
                                  onTomarFoto: onTomarFotoCerrado,
                                  onGuardar: _guardarEstadoCerrado,
                                  tomandoFoto: _ctrl.tomandoFoto,
                                  subiendoFoto: _ctrl.subiendoFotoCerrado,
                                  firmaCliente: _ctrl.firmaClienteCerrado,
                                  nombreCliente: _ctrl.nombreClienteCerrado,
                                  onFirmaClienteChanged: (bytes) => _ctrl.setFirmaCliente(esAbierto: false, bytes: bytes),
                                  onNombreClienteChanged: (value) {
                                    setState(() => _ctrl.nombreClienteCerrado = value);
                                    _ctrl.scheduleDraftSave();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        // Overlay de carga
        if (_ctrl.subiendoFotoAbierto || _ctrl.subiendoFotoCerrado)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      const Text('Subiendo foto al servidor...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Por favor espera, no cierres la pantalla', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Widgets auxiliares ──────────────────────────────────────────────────

  Widget _buildHeader(String empresa, String nombre) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.business, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(empresa, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.description, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(nombre, style: const TextStyle(fontSize: 14, color: Colors.white70))),
          ]),
          if (_ctrl.usuarioNombre != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.person, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('Responsable actual: ${_ctrl.usuarioNombre}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildCerrarCasoButton() {
    if (!_puedeCerrarCasos()) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _ctrl.casoCerrado = true),
        icon: const Icon(Icons.lock),
        label: const Text('Cerrar Caso', style: TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildGenerarReporteButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => ReportScreen(
              casoId: _ctrl.casoId!,
              grupoId: _ctrl.grupoId,
              empresaId: _ctrl.empresaId,
              centroId: _ctrl.centroId,
              casoData: _ctrl.casoData,
            ),
          ));
        },
        icon: const Icon(Icons.file_present, size: 24),
        label: const Text('Generar Reporte en PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
    );
  }
}