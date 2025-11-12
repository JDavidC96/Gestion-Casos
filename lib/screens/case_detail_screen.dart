// lib/screens/case_detail_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firebase_service.dart';
import '../services/camera_service.dart';
import '../services/geolocation_service.dart';
import '../widgets/case_state_card_firebase.dart';
import '../widgets/closed_state_card_firebase.dart';

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
  String _nivelRiesgo = 'No aplica';
  String? _recomendacionesControl;
  String? _fotoAbiertoPath;
  String? _fotoAbiertoUrl;
  Uint8List? _firmaAbierto;
  String? _firmaAbiertoUrl;  // Agregar esto
  Position? _ubicacionAbierto;
  bool _estadoAbiertoGuardado = false;

  // Estado Cerrado
  String _descripcionSolucion = '';
  String? _fotoCerradoPath;
  String? _fotoCerradoUrl;
  Uint8List? _firmaCerrado;
  String? _firmaCerradoUrl;  // Agregar esto
  Position? _ubicacionCerrado;
  bool _estadoCerradoGuardado = false;

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCaseData();
    });
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

          // Cargar estado abierto
          final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>?;
          if (estadoAbierto != null) {
            _descripcionHallazgo = estadoAbierto['descripcionHallazgo'] ?? '';
            _nivelRiesgo = estadoAbierto['nivelRiesgo'] ?? 'No aplica';
            _recomendacionesControl = estadoAbierto['recomendacionesControl'];
            _fotoAbiertoUrl = estadoAbierto['fotoUrl'];
            _estadoAbiertoGuardado = estadoAbierto['guardado'] ?? false;
            
            // Cargar firma desde base64
            if (estadoAbierto['firmaBase64'] != null) {
              _firmaAbierto = CameraService.base64ToFirma(estadoAbierto['firmaBase64']);
            }
            
            // Ubicación
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
            
            // Cargar firma desde base64
            if (estadoCerrado['firmaBase64'] != null) {
              _firmaCerrado = CameraService.base64ToFirma(estadoCerrado['firmaBase64']);
            }
            
            // Ubicación
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
      print('Error cargando caso: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando caso: $e')),
        );
      }
    }
  }

  // Tomar foto
  Future<void> _tomarFoto({required bool esEstadoAbierto}) async {
    if (_tomandoFoto) return;
    if ((esEstadoAbierto && _estadoAbiertoGuardado) || 
        (!esEstadoAbierto && _estadoCerradoGuardado)) {
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

        if (resultado['ubicacion'] != null) {
          print('Ubicación: ${GeolocationService.formatearUbicacion(resultado['ubicacion'])}');
        }
      }
    } catch (e) {
      print('Error tomando foto: $e');
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

  // Capturar firma
  void _capturarFirma({required bool esEstadoAbierto}) {
    if ((esEstadoAbierto && _estadoAbiertoGuardado) || 
        (!esEstadoAbierto && _estadoCerradoGuardado)) {
      return;
    }

    _signatureController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(esEstadoAbierto ? "Firma Inicial" : "Firma Final"),
          content: SizedBox(
            width: double.maxFinite,
            height: 200,
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.grey[200]!,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                final data = await _signatureController.toPngBytes();
                if (data != null && mounted) {
                  setState(() {
                    if (esEstadoAbierto) {
                      _firmaAbierto = data;
                    } else {
                      _firmaCerrado = data;
                    }
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Guardar Firma"),
            ),
          ],
        );
      },
    );
  }

  // Guardar estado abierto
  Future<void> _guardarEstadoAbierto() async {
    if (_casoId == null) return;

    // Validaciones
    if (_descripcionHallazgo.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La descripción del hallazgo es requerida")),
      );
      return;
    }

    if (_nivelRiesgo.isEmpty || _nivelRiesgo == 'No aplica') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un nivel de riesgo válido")),
      );
      return;
    }

    if (_fotoAbiertoUrl == null && _firmaAbierto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega al menos una foto o firma")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convertir firma a base64 si existe
      String? firmaBase64;
      if (_firmaAbierto != null) {
        firmaBase64 = CameraService.firmaToBase64(_firmaAbierto!);
      }

      final estadoAbiertoData = {
        'descripcionHallazgo': _descripcionHallazgo.trim(),
        'nivelRiesgo': _nivelRiesgo,
        'recomendacionesControl': _recomendacionesControl?.trim(),
        'fotoUrl': _fotoAbiertoUrl,
        'firmaBase64': firmaBase64, // Guardar como base64
        'ubicacion': _ubicacionAbierto != null
            ? {
                'latitude': _ubicacionAbierto!.latitude,
                'longitude': _ubicacionAbierto!.longitude,
              }
            : null,
        'guardado': true,
        'fechaGuardado': FieldValue.serverTimestamp(),
      };

      await FirebaseService.updateEstadoAbierto(_casoId!, estadoAbiertoData);

      setState(() {
        _estadoAbiertoGuardado = true;
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

  // Guardar estado cerrado
  Future<void> _guardarEstadoCerrado() async {
    if (_casoId == null) return;

    // Validaciones
    if (_descripcionSolucion.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La descripción de la solución es requerida")),
      );
      return;
    }

    if (_fotoCerradoUrl == null && _firmaCerrado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega al menos una foto o firma")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convertir firma a base64 si existe
      String? firmaBase64;
      if (_firmaCerrado != null) {
        firmaBase64 = CameraService.firmaToBase64(_firmaCerrado!);
      }

      final estadoCerradoData = {
        'descripcionSolucion': _descripcionSolucion.trim(),
        'fotoUrl': _fotoCerradoUrl,
        'firmaBase64': firmaBase64, // Guardar como base64
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
      print('Error guardando estado cerrado: $e');
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
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final empresaNombre = _casoData?['empresaNombre'] ?? "Sin empresa";
    final nombre = _casoData?['nombre'] ?? "Caso sin descripción";

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
                            nivelRiesgo: _nivelRiesgo,
                            recomendacionesControl: _recomendacionesControl,
                            fotoPath: _fotoAbiertoPath,
                            fotoUrl: _fotoAbiertoUrl,
                            firma: _firmaAbierto,
                            firmaUrl: null, // Ya no usamos firmaUrl
                            bloqueado: _estadoAbiertoGuardado,
                            onDescripcionChanged: (value) {
                              setState(() => _descripcionHallazgo = value);
                            },
                            onNivelRiesgoChanged: (value) {
                              if (value != null) {
                                setState(() => _nivelRiesgo = value);
                              }
                            },
                            onRecomendacionesChanged: (value) {
                              setState(() => _recomendacionesControl = value);
                            },
                            onTomarFoto: () => _tomarFoto(esEstadoAbierto: true),
                            onCapturarFirma: () => _capturarFirma(esEstadoAbierto: true),
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
                              firmaUrl: null, // Ya no usamos firmaUrl
                              bloqueado: _estadoCerradoGuardado,
                              onDescripcionSolucionChanged: (value) {
                                setState(() => _descripcionSolucion = value);
                              },
                              onTomarFoto: () => _tomarFoto(esEstadoAbierto: false),
                              onCapturarFirma: () => _capturarFirma(esEstadoAbierto: false),
                              onGuardar: _guardarEstadoCerrado,
                              tomandoFoto: _tomandoFoto,
                            ),

                          if (_estadoAbiertoGuardado && _estadoCerradoGuardado)
                            _buildGenerarReporteButton(),
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
        ],
      ),
    );
  }

  Widget _buildCerrarCasoButton() {
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
          Navigator.pushNamed(context, '/report', arguments: {'casoId': _casoId});
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