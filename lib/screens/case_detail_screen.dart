// lib/screens/case_detail_screen.dart
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'report_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';
import '../services/camera_service.dart';
import '../providers/auth_provider.dart';
import '../providers/interface_config_provider.dart';
import '../widgets/case_state_card_firebase.dart';
import '../widgets/closed_state_card_firebase.dart';
import '../widgets/configurable_feature.dart';
import '../services/case_draft_service.dart';


class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  String? _grupoId;
  String? _empresaId;
  String? _centroId;
  String? _casoId;
  Map<String, dynamic>? _casoData;
  bool _isLoading = false;
  bool _tomandoFoto = false;
  bool _subiendoFotoAbierto = false;  // upload Drive en progreso — estado abierto
  bool _subiendoFotoCerrado = false;  // upload Drive en progreso — estado cerrado
  bool _casoCerrado = false;
  Timer? _draftDebounce;
  bool _draftRestored = false;

  // Estado Abierto
  String _descripcionHallazgo = '';
  String _nivelPeligro = 'Medio';
  String? _recomendacionesControl;
  String? _fotoAbiertoPath;
  String? _fotoAbiertoUrl;
  Uint8List? _firmaAbierto;
  String? _firmaAbiertoUrl;   // URL Drive de la firma del inspector (estado abierto)
  Position? _ubicacionAbierto;
  bool _estadoAbiertoGuardado = false;
  String? _responsableAbiertoNombre;
  final TextEditingController _ubicacionTextoCtrl = TextEditingController();
  // Firma del cliente — estado abierto
  Uint8List? _firmaClienteAbierto;
  String? _nombreClienteAbierto;

  // Estado Cerrado
  String _descripcionSolucion = '';
  String? _fotoCerradoPath;
  String? _fotoCerradoUrl;
  Uint8List? _firmaCerrado;
  String? _firmaCerradoUrl;    // URL Drive de la firma del inspector (estado cerrado)
  Position? _ubicacionCerrado;
  bool _estadoCerradoGuardado = false;
  String? _responsableCerradoNombre;
  // Firma del cliente — estado cerrado
  Uint8List? _firmaClienteCerrado;
  String? _nombreClienteCerrado;

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

  Map<String, dynamic> _buildDraft() {
  return {
    'descripcionHallazgo': _descripcionHallazgo,
    'nivelPeligro': _nivelPeligro,
    'recomendacionesControl': _recomendacionesControl,
    'fotoAbiertoPath': _fotoAbiertoPath,
    'fotoAbiertoUrl': _fotoAbiertoUrl,
    'descripcionSolucion': _descripcionSolucion,
    'fotoCerradoPath': _fotoCerradoPath,
    'ubicacionTexto': _ubicacionTextoCtrl.text,
    'fotoCerradoUrl': _fotoCerradoUrl,
    'nombreClienteAbierto': _nombreClienteAbierto,
    'nombreClienteCerrado': _nombreClienteCerrado,
  };
}

// Método para programar guardado automático del borrador
void _scheduleDraftSave() {
  if (_casoId == null) return;

  _draftDebounce?.cancel();
  _draftDebounce = Timer(const Duration(milliseconds: 600), () async {
    try {
      await CaseDraftService.instance.saveDraft(_casoId!, _buildDraft());
    } catch (_) {
      // silencioso
    }
  });
}

// Método para restaurar borrador si existe
Future<void> _restoreDraftIfAny() async {
  if (_casoId == null || _draftRestored) return;

  final draft = await CaseDraftService.instance.getDraft(_casoId!);
  _draftRestored = true;
  if (draft == null) return;
  if (!mounted) return;

  setState(() {
    if (!_estadoAbiertoGuardado) {
      _descripcionHallazgo = draft['descripcionHallazgo'] ?? _descripcionHallazgo;
      _nivelPeligro = draft['nivelPeligro'] ?? _nivelPeligro;
      final ut = draft['ubicacionTexto'];
      if (ut != null && _ubicacionTextoCtrl.text.isEmpty) {
        _ubicacionTextoCtrl.text = ut;
      }
      _recomendacionesControl = draft['recomendacionesControl'] ?? _recomendacionesControl;
      // Solo restaurar foto del borrador si Firestore no trajo una URL ya guardada
      if (_fotoAbiertoUrl == null) {
        _fotoAbiertoPath = draft['fotoAbiertoPath'] ?? _fotoAbiertoPath;
        _fotoAbiertoUrl  = draft['fotoAbiertoUrl']  ?? _fotoAbiertoUrl;
      }
      _nombreClienteAbierto = draft['nombreClienteAbierto'] ?? _nombreClienteAbierto;
    }

    if (!_estadoCerradoGuardado) {
      _descripcionSolucion = draft['descripcionSolucion'] ?? _descripcionSolucion;
      // Solo restaurar foto del borrador si Firestore no trajo una URL ya guardada
      if (_fotoCerradoUrl == null) {
        _fotoCerradoPath = draft['fotoCerradoPath'] ?? _fotoCerradoPath;
        _fotoCerradoUrl  = draft['fotoCerradoUrl']  ?? _fotoCerradoUrl;
      }
      _nombreClienteCerrado = draft['nombreClienteCerrado'] ?? _nombreClienteCerrado;
    }
  });
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

  // Descarga firma desde Drive URL y la convierte a Uint8List
  // Usa la misma lógica que PdfService para convertir URLs de Drive
  static String? _convertirUrlDrive(String? url) {
    if (url == null) return null;
    if (url.contains('drive.google.com')) {
      final fileId = RegExp(r'\/d\/([a-zA-Z0-9-_]+)').firstMatch(url)?.group(1);
      if (fileId != null) {
        return 'https://drive.google.com/uc?export=download&id=$fileId';
      }
    }
    return url;
  }

  Future<Uint8List?> _descargarFirmaDesdeDrive(String? driveUrl) async {
    final directUrl = _convertirUrlDrive(driveUrl);
    if (directUrl == null) return null;
    try {
      final response = await http.get(Uri.parse(directUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      print('⚠️ No se pudo descargar firma desde Drive: \$e');
    }
    return null;
  }

  // Método para cargar datos del usuario actual
  Future<void> _loadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userData = authProvider.userData;
    
    if (userData != null) {
      _usuarioId = userData['uid'];
      _usuarioNombre = userData['displayName'] ?? 'Usuario';
      _responsableAbiertoNombre = _usuarioNombre;
      _responsableCerradoNombre = _usuarioNombre;

      // Firma desde base64 (si existe en el perfil)
      if (userData['firmaBase64'] != null) {
        _usuarioFirma = CameraService.base64ToFirma(userData['firmaBase64']);
        if (mounted) setState(() {
          _firmaAbierto = _usuarioFirma;
          _firmaCerrado = _usuarioFirma;
        });
      }

      // Firma desde Drive URL (guardada en el perfil del inspector)
      final firmaUrl = userData['firmaUrl'] as String?;
      if (firmaUrl != null) {
        _firmaAbiertoUrl = firmaUrl;
        _firmaCerradoUrl = firmaUrl;
        // Descargar imagen para mostrar en el card
        final bytes = await _descargarFirmaDesdeDrive(firmaUrl);
        if (bytes != null && mounted) {
          setState(() {
            _usuarioFirma = bytes;
            _firmaAbierto ??= bytes;   // solo si no había firma base64
            _firmaCerrado ??= bytes;
          });
        }
      }
    }
  }

  // Método para cargar configuración de interfaz
  void _loadInterfaceConfig() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
    
    if (authProvider.grupoId != null) {
      if (authProvider.grupoId != null) configProvider.loadConfig(authProvider.grupoId!);
    }
  }

  // Método para cargar datos del caso desde Firestore
  void _loadCaseData() {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    if (args != null) {
      _grupoId   = args['grupoId']   as String?;
      _empresaId = args['empresaId'] as String?;
      _centroId  = args['centroId']  as String?;
      _casoId    = args['casoId']    as String?;
      if (_casoId != null) {
        _loadFromFirestore();
      }
    }
  }

  // Método para cargar datos del caso desde Firestore y actualizar el estado local
  Future<void> _loadFromFirestore() async {
    if (_casoId == null) return;

    try {
      final doc = await FirebaseService.getCasoById(
        _grupoId ?? '', _empresaId ?? '', _centroId ?? '', _casoId!);
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
            _ubicacionTextoCtrl.text = estadoAbierto['ubicacionTexto'] ?? '';
            _nombreClienteAbierto = estadoAbierto['nombreCliente'];
            
            if (estadoAbierto['firmaClienteBase64'] != null) {
              _firmaClienteAbierto = CameraService.base64ToFirma(estadoAbierto['firmaClienteBase64']);
            }
            
            if (estadoAbierto['firmaBase64'] != null) {
              _firmaAbierto = CameraService.base64ToFirma(estadoAbierto['firmaBase64']);
            }
            // Cargar URL Drive de firma del inspector si existe en Firestore
            if (estadoAbierto['firmaUrl'] != null) {
              _firmaAbiertoUrl = estadoAbierto['firmaUrl'] as String?;
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

          // Cargar estado cerrado
          final estadoCerrado = data['estadoCerrado'] as Map<String, dynamic>?;
          if (estadoCerrado != null) {
            _descripcionSolucion = estadoCerrado['descripcionSolucion'] ?? '';
            _fotoCerradoUrl = estadoCerrado['fotoUrl'];
            _estadoCerradoGuardado = estadoCerrado['guardado'] ?? false;
            _responsableCerradoNombre = estadoCerrado['usuarioNombre'] ?? _usuarioNombre;
            _nombreClienteCerrado = estadoCerrado['nombreCliente'];

            if (estadoCerrado['firmaClienteBase64'] != null) {
              _firmaClienteCerrado = CameraService.base64ToFirma(estadoCerrado['firmaClienteBase64']);
            }
            
            if (estadoCerrado['firmaBase64'] != null) {
              _firmaCerrado = CameraService.base64ToFirma(estadoCerrado['firmaBase64']);
            }
            // Cargar URL Drive de firma del inspector si existe en Firestore
            if (estadoCerrado['firmaUrl'] != null) {
              _firmaCerradoUrl = estadoCerrado['firmaUrl'] as String?;
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
        await _restoreDraftIfAny();
        // Descargar firmas desde Drive si hay URLs guardadas
        await _cargarFirmasDesdeDrive();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando caso: $e')),
        );
      }
    }
  }

  /// Descarga las firmas del inspector desde Drive y actualiza el estado.
  Future<void> _cargarFirmasDesdeDrive() async {
    if (_firmaAbiertoUrl != null && _firmaAbierto == null) {
      final bytes = await _descargarFirmaDesdeDrive(_firmaAbiertoUrl);
      if (bytes != null && mounted) setState(() => _firmaAbierto = bytes);
    }
    if (_firmaCerradoUrl != null && _firmaCerrado == null) {
      final bytes = await _descargarFirmaDesdeDrive(_firmaCerradoUrl);
      if (bytes != null && mounted) setState(() => _firmaCerrado = bytes);
    }
  }

  // Método para tomar foto, con control de estado para evitar múltiples llamadas simultáneas y validación de requisitos
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
      // PASO 1: captura instantánea — la cámara se cierra y vemos la preview
      final resultado = await CameraService.tomarFoto();

      if (resultado == null || !mounted) return;

      final xFile = resultado['xFile'] as XFile?;
      if (xFile == null) {
        print('❌ xFile es null — no se puede subir a Drive');
        return;
      }

      setState(() {
        _tomandoFoto = false;
        if (esEstadoAbierto) {
          _fotoAbiertoPath = resultado['fotoPath'];
          _fotoAbiertoUrl = null;          // aún no tenemos URL
          _ubicacionAbierto = resultado['ubicacion'];
          _subiendoFotoAbierto = true;     // activa el loading de upload
        } else {
          _fotoCerradoPath = resultado['fotoPath'];
          _fotoCerradoUrl = null;
          _ubicacionCerrado = resultado['ubicacion'];
          _subiendoFotoCerrado = true;
        }
      });

      // PASO 2: upload a Drive con loading visible en pantalla
      final driveUrl = await CameraService.subirFotoADrive(xFile);

      if (!mounted) return;

      if (driveUrl != null) {
        setState(() {
          if (esEstadoAbierto) {
            _fotoAbiertoUrl = driveUrl;
          } else {
            _fotoCerradoUrl = driveUrl;
          }
        });
        _scheduleDraftSave();
      } else {
        // Drive falló: la foto se ve pero no se guardará en Firebase
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No se pudo subir la foto al servidor. Intenta de nuevo antes de guardar.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _tomandoFoto = false;
          _subiendoFotoAbierto = false;
          _subiendoFotoCerrado = false;
        });
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
    // Aceptar foto si existe URL de Drive O path local (Drive puede demorar el redirect)
    final tieneFotoAbierto = _fotoAbiertoUrl != null || _fotoAbiertoPath != null;
    if (habilitarFotos && !_estadoAbiertoGuardado && !tieneFotoAbierto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega una foto del hallazgo")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Subir firma del cliente a Drive si existe y aún no tiene URL
      String? firmaClienteUrl;
      if (_firmaClienteAbierto != null) {
        try {
          firmaClienteUrl = await CameraService.subirFirmaADrive(
            firmaBytes: _firmaClienteAbierto!,
            nombre: 'firma_cliente_${_casoId}_abierto',
          );
        } catch (e) {
          print('Advertencia: no se pudo subir firma cliente a Drive: $e');
        }
      }

      final estadoAbiertoData = {
        'descripcionHallazgo': _descripcionHallazgo.trim(),
        'recomendacionesControl': _recomendacionesControl?.trim(),
        'fotoUrl': _fotoAbiertoUrl,
        'firmaBase64': _usuarioFirma != null ? CameraService.firmaToBase64(_usuarioFirma!) : null,
        if (_firmaAbiertoUrl != null) 'firmaUrl': _firmaAbiertoUrl,
        'usuarioId': _usuarioId,
        'usuarioNombre': _usuarioNombre,
        'ubicacionTexto': _ubicacionTextoCtrl.text.trim(),
        'ubicacion': _ubicacionAbierto != null
            ? {
                'latitude': _ubicacionAbierto!.latitude,
                'longitude': _ubicacionAbierto!.longitude,
              }
            : null,
        'guardado': true,
        'fechaGuardado': FieldValue.serverTimestamp(),
        // Firma del cliente
        if (_firmaClienteAbierto != null)
          'firmaClienteBase64': CameraService.firmaToBase64(_firmaClienteAbierto!),
        if (firmaClienteUrl != null) 'firmaClienteUrl': firmaClienteUrl,
        if (_nombreClienteAbierto != null && _nombreClienteAbierto!.isNotEmpty)
          'nombreCliente': _nombreClienteAbierto,
      };

      if (mostrarNivelPeligro) {
        estadoAbiertoData['nivelPeligro'] = _nivelPeligro;
      }

      await FirebaseService.updateEstadoAbierto(
        _grupoId ?? '', _empresaId ?? '', _centroId ?? '', _casoId!, estadoAbiertoData);

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
    // Aceptar foto si existe URL de Drive O path local (Drive puede demorar el redirect)
    final tieneFotoCerrado = _fotoCerradoUrl != null || _fotoCerradoPath != null;
    if (habilitarFotos && !_estadoCerradoGuardado && !tieneFotoCerrado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega una foto de la solución")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Subir firma del cliente a Drive si existe
      String? firmaClienteUrl;
      if (_firmaClienteCerrado != null) {
        try {
          firmaClienteUrl = await CameraService.subirFirmaADrive(
            firmaBytes: _firmaClienteCerrado!,
            nombre: 'firma_cliente_${_casoId}_cerrado',
          );
        } catch (e) {
          print('Advertencia: no se pudo subir firma cliente a Drive: $e');
        }
      }

      final estadoCerradoData = {
        'descripcionSolucion': _descripcionSolucion.trim(),
        'fotoUrl': _fotoCerradoUrl,
        'firmaBase64': _usuarioFirma != null ? CameraService.firmaToBase64(_usuarioFirma!) : null,
        if (_firmaCerradoUrl != null) 'firmaUrl': _firmaCerradoUrl,
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
        // Firma del cliente
        if (_firmaClienteCerrado != null)
          'firmaClienteBase64': CameraService.firmaToBase64(_firmaClienteCerrado!),
        if (firmaClienteUrl != null) 'firmaClienteUrl': firmaClienteUrl,
        if (_nombreClienteCerrado != null && _nombreClienteCerrado!.isNotEmpty)
          'nombreCliente': _nombreClienteCerrado,
      };

      await FirebaseService.updateEstadoCerrado(
        _grupoId ?? '', _empresaId ?? '', _centroId ?? '', _casoId!, estadoCerradoData);

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
        _scheduleDraftSave();
      }
    } : _nivelPeligroDeshabilitado;

    return Stack(
      children: [
        Scaffold(
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
                            firmaUrl: _firmaAbiertoUrl,
                            bloqueado: _estadoAbiertoGuardado,
                            usuarioNombre: _responsableAbiertoNombre,
                            ubicacionController: _ubicacionTextoCtrl,
                            onUbicacionChanged: (value) {
                              _scheduleDraftSave();
                            },
                            onDescripcionChanged: (value) {
                              setState(() => _descripcionHallazgo = value);
                              _scheduleDraftSave();
                            },
                            onnivelPeligroChanged: onNivelPeligroChanged,
                            onRecomendacionesChanged: (value) {
                              setState(() => _recomendacionesControl = value);
                              _scheduleDraftSave();
                            },
                            onTomarFoto: onTomarFotoAbierto,
                            onGuardar: _guardarEstadoAbierto,
                            tomandoFoto: _tomandoFoto,
                            subiendoFoto: _subiendoFotoAbierto,
                            // Firma del cliente
                            firmaCliente: _firmaClienteAbierto,
                            nombreCliente: _nombreClienteAbierto,
                            onFirmaClienteChanged: (bytes) {
                              setState(() => _firmaClienteAbierto = bytes);
                            },
                            onNombreClienteChanged: (value) {
                              setState(() => _nombreClienteAbierto = value);
                              _scheduleDraftSave();
                            },
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
                              firmaUrl: _firmaCerradoUrl,
                              bloqueado: _estadoCerradoGuardado,
                              usuarioNombre: _responsableCerradoNombre,
                              onDescripcionSolucionChanged: (value) {
                                setState(() => _descripcionSolucion = value);
                                _scheduleDraftSave();
                              },
                              onTomarFoto: onTomarFotoCerrado,
                              onGuardar: _guardarEstadoCerrado,
                              tomandoFoto: _tomandoFoto,
                              subiendoFoto: _subiendoFotoCerrado,
                              // Firma del cliente
                              firmaCliente: _firmaClienteCerrado,
                              nombreCliente: _nombreClienteCerrado,
                              onFirmaClienteChanged: (bytes) {
                                setState(() => _firmaClienteCerrado = bytes);
                              },
                              onNombreClienteChanged: (value) {
                                setState(() => _nombreClienteCerrado = value);
                                _scheduleDraftSave();
                              },
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
    ),

        // ── Overlay de carga mientras se sube la foto a Drive ──
        if (_subiendoFotoAbierto || _subiendoFotoCerrado)
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
                      const Text(
                        'Subiendo foto al servidor...',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Por favor espera, no cierres la pantalla',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
    _ubicacionTextoCtrl.dispose();
    _draftDebounce?.cancel();
    _signatureController.dispose();
    super.dispose();
  }
}