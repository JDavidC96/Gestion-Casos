// screens/case_detail_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/case_provider.dart';
import '../models/case_model.dart';
import '../models/case_detail_data.dart';
import '../services/geolocation_service.dart';
import '../services/camera_service.dart';
import '../widgets/case_state_card.dart';
import '../widgets/closed_state_card.dart';

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  // Datos para estado abierto y cerrado
  CaseDetailData _datosAbierto = CaseDetailData(
    descripcionHallazgo: '',
    nivelRiesgo: 'No aplica',
    fechaCreacion: DateTime.now(),
  );
  
  CaseDetailData _datosCerrado = CaseDetailData(
    descripcionHallazgo: '',
    nivelRiesgo: 'No aplica', 
    fechaCreacion: DateTime.now(),
  );

  bool _casoCerrado = false;
  bool _tomandoFoto = false;
  bool _casoAbiertoGuardado = false;
  bool _casoCerradoGuardado = false;

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _cargarDatosExistentes();
  }

  void _cargarDatosExistentes() {
    // Aquí puedes cargar datos existentes si el caso ya fue guardado parcialmente
  }

  // Tomar foto sin marca de agua pero con geolocalización
  Future<void> _tomarFoto({required bool esEstadoAbierto}) async {
    if (_tomandoFoto) return;
    
    setState(() => _tomandoFoto = true);

    try {
      final resultado = await CameraService.tomarFoto();
      
      if (resultado != null) {
        final foto = File((resultado['foto'] as XFile).path);
        final ubicacion = resultado['ubicacion'] as Position?;

        setState(() {
          if (esEstadoAbierto) {
            _datosAbierto = _datosAbierto.copyWith(
              foto: foto,
              ubicacion: ubicacion,
            );
          } else {
            _datosCerrado = _datosCerrado.copyWith(
              foto: foto,
              ubicacion: ubicacion,
            );
          }
        });

        if (ubicacion != null) {
          print('Ubicación guardada: ${GeolocationService.formatearUbicacion(ubicacion)}');
        }
      }
    } catch (e) {
      print('Error tomando foto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al tomar foto: $e')),
      );
    } finally {
      setState(() => _tomandoFoto = false);
    }
  }

  // Capturar firma
  void _capturarFirma({required bool esEstadoAbierto}) {
    if ((esEstadoAbierto && _casoAbiertoGuardado) || 
        (!esEstadoAbierto && _casoCerradoGuardado)) {
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
                if (data != null) {
                  setState(() {
                    if (esEstadoAbierto) {
                      _datosAbierto = _datosAbierto.copyWith(firma: data);
                    } else {
                      _datosCerrado = _datosCerrado.copyWith(firma: data);
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

  // Validar y guardar estado
  bool _validarDatos(CaseDetailData datos, bool esEstadoAbierto) {
    if (datos.descripcionHallazgo.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(esEstadoAbierto 
          ? "La descripción del hallazgo es requerida" 
          : "La descripción de la solución es requerida")),
      );
      return false;
    }

    if (esEstadoAbierto && datos.nivelRiesgo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El nivel de riesgo es requerido")),
      );
      return false;
    }

    if (datos.foto == null && datos.firma == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agregue al menos una foto o firma")),
      );
      return false;
    }

    return true;
  }

  void _guardarEstadoAbierto() {
    if (!_validarDatos(_datosAbierto, true)) return;

    setState(() {
      _casoAbiertoGuardado = true;
      _datosAbierto = _datosAbierto.copyWith(guardado: true);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Estado abierto guardado")),
    );
  }

  void _guardarEstadoCerrado() {
    if (!_validarDatos(_datosCerrado, false)) return;

    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final casoActual = args?["caso"] as Case?;

    setState(() {
      _casoCerradoGuardado = true;
      _datosCerrado = _datosCerrado.copyWith(guardado: true);
    });

    if (casoActual != null) {
      final caseProvider = Provider.of<CaseProvider>(context, listen: false);
      caseProvider.marcarCasoComoCerrado(casoActual.id, DateTime.now());
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Estado cerrado guardado")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final caso = args?["caso"] as Case?;
    
    final empresa = caso?.empresaNombre ?? "Sin empresa";
    final nombre = caso?.nombre ?? "Caso sin descripción";

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF512F), Color(0xFFF09819)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Header informativo
            _buildHeader(empresa, nombre),
            
            // Contenido desplazable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Estado Abierto
                    CaseStateCard(
                      titulo: "Estado Abierto",
                      subtitulo: "Complete la información inicial del caso",
                      data: _datosAbierto,
                      esEstadoAbierto: true,
                      bloqueado: _casoAbiertoGuardado,
                      colorFondo: Colors.blue,
                      onDescripcionChanged: (value) {
                        setState(() {
                          _datosAbierto = _datosAbierto.copyWith(descripcionHallazgo: value);
                        });
                      },
                      onNivelRiesgoChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _datosAbierto = _datosAbierto.copyWith(nivelRiesgo: value);
                          });
                        }
                      },
                      onRecomendacionesChanged: (value) {
                        setState(() {
                          _datosAbierto = _datosAbierto.copyWith(recomendacionesControl: value);
                        });
                      },
                      onTomarFoto: () => _tomarFoto(esEstadoAbierto: true),
                      onCapturarFirma: () => _capturarFirma(esEstadoAbierto: true),
                      onGuardar: _guardarEstadoAbierto,
                      tomandoFoto: _tomandoFoto,
                    ),

                    // Botón para cerrar caso
                    if (_casoAbiertoGuardado && !_casoCerrado) 
                      _buildCerrarCasoButton(),

                    // Estado Cerrado
                    if (_casoCerrado)
                      ClosedStateCard(
                        titulo: "Estado Cerrado", 
                        subtitulo: "Complete la información de cierre del caso",
                        data: _datosCerrado,
                        bloqueado: _casoCerradoGuardado,
                        colorFondo: Colors.green,
                        onDescripcionSolucionChanged: (value) {
                          setState(() {
                            _datosCerrado = _datosCerrado.copyWith(descripcionHallazgo: value);
                          });
                        },
                        onTomarFoto: () => _tomarFoto(esEstadoAbierto: false),
                        onCapturarFirma: () => _capturarFirma(esEstadoAbierto: false),
                        onGuardar: _guardarEstadoCerrado,
                        tomandoFoto: _tomandoFoto,
                      ),

                    // Botón generar reporte
                    if (_casoAbiertoGuardado && _casoCerradoGuardado)
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
          setState(() {
            _casoCerrado = true;
          });
        },
        icon: const Icon(Icons.lock),
        label: const Text(
          "Cerrar Caso",
          style: TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
          Navigator.pushNamed(context, '/report');
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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