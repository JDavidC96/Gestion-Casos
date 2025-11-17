// lib/screens/case_detail_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'report_screen.dart';
import '../services/firebase_service.dart';
import '../services/camera_service.dart';
import '../providers/auth_provider.dart';
import '../providers/interface_config_provider.dart';
import '../widgets/case_state_card_firebase.dart';
import '../widgets/closed_state_card_firebase.dart';
import '../widgets/configurable_feature.dart';

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  String? _casoId;
  Map<String, dynamic>? _casoData;
  bool _isLoading = false;
  bool _tomandoFoto = false;
  bool _casoCerrado = false;

  // Estado Abierto
  String _descripcionHallazgo = '';
  String _nivelPeligro = 'Medio';
  String? _recomendacionesControl;
  String? _fotoAbiertoPath;
  String? _fotoAbiertoUrl;
  Uint8List? _firmaAbierto;
  Position? _ubicacionAbierto;
  bool _estadoAbiertoGuardado = false;
  String? _responsableAbiertoNombre;

  // Estado Cerrado
  String _descripcionSolucion = '';
  String? _fotoCerradoPath;
  String? _fotoCerradoUrl;
  Uint8List? _firmaCerrado;
  Position? _ubicacionCerrado;
  bool _estadoCerradoGuardado = false;
  String? _responsableCerradoNombre;

  // Información del usuario actual
  String? _usuarioId;
  String? _usuarioNombre;
  Uint8List? _usuarioFirma;

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // Método para verificar permisos de cierre de casos
  bool _puedeCerrarCasos() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Admin puede cerrar casos en su grupo, super_admin en todos, inspectores según su rol
    return authProvider.isAdmin || 
           authProvider.isSuperAdmin || 
           authProvider.isAnyInspector;
  }

  // Callbacks que no hacen nada para características deshabilitadas
  void _tomarFotoDeshabilitada() {
    // No hace nada - se llama cuando las fotos están deshabilitadas
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La función de fotos está deshabilitada')),
    );
  }

  void _nivelPeligroDeshabilitado(String? value) {
    // No hace nada - se llama cuando el nivel de peligro está deshabilitado
  }

  void _firmaDeshabilitada() {
    // No hace nada - se llama cuando las firmas están deshabilitadas
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La función de firmas está deshabilitada')),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCaseData();
      _loadUserData();
      _loadInterfaceConfig();
    });
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userData = authProvider.userData;
    
    if (userData != null) {
      setState(() {
        _usuarioId = userData['uid'];
        _usuarioNombre = userData['displayName'] ?? 'Usuario';
        
        if (userData['firmaBase64'] != null) {
          _usuarioFirma = CameraService.base64ToFirma(userData['firmaBase64']);
          _firmaAbierto = _usuarioFirma;
          _firmaCerrado = _usuarioFirma;
        }
        
        _responsableAbiertoNombre = _usuarioNombre;
        _responsableCerradoNombre = _usuarioNombre;
      });
    }
  }

  void _loadInterfaceConfig() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
    
    if (authProvider.grupoId != null) {
      configProvider.loadConfig(authProvider.grupoId!);
    }
  }

  void _loadCaseData() {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    if (args != null) {
      _casoId = args['casoId'] as String?;
      if (_casoId != null) {
        _loadFromFirestore();
      }
    }
  }

  Future<void> _loadFromFirestore() async {
    if (_casoId == null) return;

    try {
      final doc = await FirebaseService.getCasoById(_casoId!);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _casoData = data;
          _casoCerrado = data['cerrado'] ?? false;

          final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>?;
          if (estadoAbierto != null) {
            _descripcionHallazgo = estadoAbierto['descripcionHallazgo'] ?? '';
            _nivelPeligro = estadoAbierto['nivelPeligro'] ?? _nivelPeligro;
            _recomendacionesControl = estadoAbierto['recomendacionesControl'];
            _fotoAbiertoUrl = estadoAbierto['fotoUrl'];
            _estadoAbiertoGuardado = estadoAbierto['guardado'] ?? false;
            _responsableAbiertoNombre = estadoAbierto['usuarioNombre'] ?? _usuarioNombre;
            
            if (estadoAbierto['firmaBase64'] != null) {
              _firmaAbierto = CameraService.base64ToFirma(estadoAbierto['firmaBase64']);
            }
            
            if (estadoAbierto['ubicacion'] != null) {
              final ub = estadoAbierto['ubicacion'];
              _ubicacionAbierto = Position(
                latitude: ub['latitude'],
                longitude: ub['longitude'],
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0,
              );
            }
          }

          final estadoCerrado = data['estadoCerrado'] as Map<String, dynamic>?;
          if (estadoCerrado != null) {
            _descripcionSolucion = estadoCerrado['descripcionSolucion'] ?? '';
            _fotoCerradoUrl = estadoCerrado['fotoUrl'];
            _estadoCerradoGuardado = estadoCerrado['guardado'] ?? false;
            _responsableCerradoNombre = estadoCerrado['usuarioNombre'] ?? _usuarioNombre;
            
            if (estadoCerrado['firmaBase64'] != null) {
              _firmaCerrado = CameraService.base64ToFirma(estadoCerrado['firmaBase64']);
            }
            
            if (estadoCerrado['ubicacion'] != null) {
              final ub = estadoCerrado['ubicacion'];
              _ubicacionCerrado = Position(
                latitude: ub['latitude'],
                longitude: ub['longitude'],
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0,
              );
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando caso: $e')),
        );
      }
    }
  }

  Future<void> _tomarFoto({required bool esEstadoAbierto}) async {
    if (_tomandoFoto) return;
    if ((esEstadoAbierto && _estadoAbiertoGuardado) || 
        (!esEstadoAbierto && _estadoCerradoGuardado)) {
      return;
    }

    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
    if (!configProvider.isFeatureEnabled('habilitarFotos')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La función de fotos está deshabilitada')),
      );
      return;
    }

    setState(() => _tomandoFoto = true);

    try {
      final resultado = await CameraService.tomarFoto();
      
      if (resultado != null && mounted) {
        setState(() {
          if (esEstadoAbierto) {
            _fotoAbiertoPath = resultado['fotoPath'];
            _fotoAbiertoUrl = resultado['driveUrl'];
            _ubicacionAbierto = resultado['ubicacion'];
          } else {
            _fotoCerradoPath = resultado['fotoPath'];
            _fotoCerradoUrl = resultado['driveUrl'];
            _ubicacionCerrado = resultado['ubicacion'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _tomandoFoto = false);
      }
    }
  }

  void _capturarFirma() {
    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
    if (!configProvider.isFeatureEnabled('habilitarFirmas')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La función de firmas está deshabilitada')),
      );
      return;
    }
    // Aquí iría la lógica para capturar firma si estuviera habilitada
  }

  Future<void> _guardarEstadoAbierto() async {
    if (_casoId == null) return;

    // Verificar permisos
    if (!_puedeCerrarCasos()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para guardar estados de casos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descripcionHallazgo.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La descripción del hallazgo es requerida")),
      );
      return;
    }

    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
    final mostrarNivelPeligro = configProvider.isFeatureEnabled('mostrarnivelPeligro');
    
    if (mostrarNivelPeligro && (_nivelPeligro.isEmpty || _nivelPeligro == 'No aplica')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un Nivel de peligro válido")),
      );
      return;
    }

    final habilitarFotos = configProvider.isFeatureEnabled('habilitarFotos');
    if (habilitarFotos && _fotoAbiertoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega una foto del hallazgo")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final estadoAbiertoData = {
        'descripcionHallazgo': _descripcionHallazgo.trim(),
        'recomendacionesControl': _recomendacionesControl?.trim(),
        'fotoUrl': _fotoAbiertoUrl,
        'firmaBase64': _usuarioFirma != null ? CameraService.firmaToBase64(_usuarioFirma!) : null,
        'usuarioId': _usuarioId,
        'usuarioNombre': _usuarioNombre,
        'ubicacion': _ubicacionAbierto != null
            ? {
                'latitude': _ubicacionAbierto!.latitude,
                'longitude': _ubicacionAbierto!.longitude,
              }
            : null,
        'guardado': true,
        'fechaGuardado': FieldValue.serverTimestamp(),
      };

      if (mostrarNivelPeligro) {
        estadoAbiertoData['nivelPeligro'] = _nivelPeligro;
      }

      await FirebaseService.updateEstadoAbierto(_casoId!, estadoAbiertoData);

      setState(() {
        _estadoAbiertoGuardado = true;
        _responsableAbiertoNombre = _usuarioNombre;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Estado abierto guardado exitosamente"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error guardando estado abierto: $e');
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

  Future<void> _guardarEstadoCerrado() async {
    if (_casoId == null) return;

    // Verificar permisos
    if (!_puedeCerrarCasos()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para cerrar casos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descripcionSolucion.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La descripción de la solución es requerida")),
      );
      return;
    }

    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
    final habilitarFotos = configProvider.isFeatureEnabled('habilitarFotos');
    if (habilitarFotos && _fotoCerradoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega una foto de la solución")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final estadoCerradoData = {
        'descripcionSolucion': _descripcionSolucion.trim(),
        'fotoUrl': _fotoCerradoUrl,
        'firmaBase64': _usuarioFirma != null ? CameraService.firmaToBase64(_usuarioFirma!) : null,
        'usuarioId': _usuarioId,
        'usuarioNombre': _usuarioNombre,
        'ubicacion': _ubicacionCerrado != null
            ? {
                'latitude': _ubicacionCerrado!.latitude,
                'longitude': _ubicacionCerrado!.longitude,
              }
            : null,
        'guardado': true,
        'fechaGuardado': FieldValue.serverTimestamp(),
      };

      await FirebaseService.updateEstadoCerrado(_casoId!, estadoCerradoData);

      setState(() {
        _estadoCerradoGuardado = true;
        _casoCerrado = true;
        _responsableCerradoNombre = _usuarioNombre;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Caso cerrado exitosamente"),
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
    final empresaNombre = _casoData?['empresaNombre'] ?? "Sin empresa";
    final nombre = _casoData?['nombre'] ?? "Caso sin descripción";
    final configProvider = Provider.of<InterfaceConfigProvider>(context);
    final mostrarNivelPeligro = configProvider.isFeatureEnabled('mostrarnivelPeligro');
    final habilitarFotos = configProvider.isFeatureEnabled('habilitarFotos');
    final habilitarFirmas = configProvider.isFeatureEnabled('habilitarFirmas');

    // Callbacks condicionales
    final onTomarFotoAbierto = habilitarFotos ? () => _tomarFoto(esEstadoAbierto: true) : _tomarFotoDeshabilitada;
    final onTomarFotoCerrado = habilitarFotos ? () => _tomarFoto(esEstadoAbierto: false) : _tomarFotoDeshabilitada;
    final onNivelPeligroChanged = mostrarNivelPeligro ? (String? value) {
      if (value != null) {
        setState(() => _nivelPeligro = value);
      }
    } : _nivelPeligroDeshabilitado;
    final onCapturarFirma = habilitarFirmas ? _capturarFirma : _firmaDeshabilitada;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          nombre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFF512F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF512F), Color(0xFFF09819)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  _buildHeader(empresaNombre, nombre),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Estado Abierto
                          CaseStateCardFirebase(
                            titulo: "Estado Abierto",
                            subtitulo: "Complete la información inicial del caso",
                            descripcionHallazgo: _descripcionHallazgo,
                            nivelPeligro: _nivelPeligro,
                            recomendacionesControl: _recomendacionesControl,
                            fotoPath: _fotoAbiertoPath,
                            fotoUrl: _fotoAbiertoUrl,
                            firma: _firmaAbierto,
                            firmaUrl: null,
                            bloqueado: _estadoAbiertoGuardado,
                            usuarioNombre: _responsableAbiertoNombre,
                            onDescripcionChanged: (value) {
                              setState(() => _descripcionHallazgo = value);
                            },
                            onnivelPeligroChanged: onNivelPeligroChanged,
                            onRecomendacionesChanged: (value) {
                              setState(() => _recomendacionesControl = value);
                            },
                            onTomarFoto: onTomarFotoAbierto,
                            onCapturarFirma: onCapturarFirma,
                            onGuardar: _guardarEstadoAbierto,
                            tomandoFoto: _tomandoFoto,
                          ),

                          if (_estadoAbiertoGuardado && !_casoCerrado)
                            _buildCerrarCasoButton(),

                          if (_casoCerrado)
                            ClosedStateCardFirebase(
                              titulo: "Estado Cerrado",
                              subtitulo: "Complete la información de cierre del caso",
                              descripcionSolucion: _descripcionSolucion,
                              fotoPath: _fotoCerradoPath,
                              fotoUrl: _fotoCerradoUrl,
                              firma: _firmaCerrado,
                              firmaUrl: null,
                              bloqueado: _estadoCerradoGuardado,
                              usuarioNombre: _responsableCerradoNombre,
                              onDescripcionSolucionChanged: (value) {
                                setState(() => _descripcionSolucion = value);
                              },
                              onTomarFoto: onTomarFotoCerrado,
                              onCapturarFirma: onCapturarFirma,
                              onGuardar: _guardarEstadoCerrado,
                              tomandoFoto: _tomandoFoto,
                            ),

                          // Botón de generar reporte configurable
                          ConfigurableFeature(
                            feature: 'habilitarReportes',
                            child: _estadoAbiertoGuardado && _estadoCerradoGuardado
                                ? _buildGenerarReporteButton()
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

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
          Row(
            children: [
              const Icon(Icons.business, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  empresa,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.description, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          if (_usuarioNombre != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Responsable actual: $_usuarioNombre',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
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
        onPressed: () {
          setState(() => _casoCerrado = true);
        },
        icon: const Icon(Icons.lock),
        label: const Text("Cerrar Caso", style: TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
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
          Navigator.push(context,
          MaterialPageRoute(
            builder: (context) => ReportScreen(casoId: _casoId!),
          ),
          );
        },
        icon: const Icon(Icons.file_present, size: 24),
        label: const Text(
          "Generar Reporte en Excel",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }
}