// lib/screens/report_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/firebase_service.dart';
import '../models/case_model.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';

class ReportScreen extends StatefulWidget {
  final String? casoId;
  final String? grupoId;
  final String? empresaId;
  final String? centroId;
  final Map<String, dynamic>? casoData;

  const ReportScreen({
    super.key,
    this.casoId,
    this.grupoId,
    this.empresaId,
    this.centroId,
    this.casoData,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _isGenerating = false;
  bool _isSharing = false;
  Map<String, dynamic>? _casoData;
  Case? _casoObjeto;
  bool _isLoading = true;

  // ── Caché del PDF pre-construido ─────────────────────────────────────────
  bool _isPreparing = false;          // descargando imágenes y compilando PDF
  Uint8List? _pdfBytes;               // bytes listos para usar sin recompilar
  String? _pdfNombre;                 // nombre del archivo
  List<String> _advertencias = [];    // advertencias de la última compilación

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final String? id        = widget.casoId    ?? args?['casoId'];
    final String? grupoId   = widget.grupoId   ?? args?['grupoId'];
    final String? empresaId = widget.empresaId ?? args?['empresaId'];
    final String? centroId  = widget.centroId  ?? args?['centroId'];

    // Si tenemos el path completo, siempre recargar desde Firestore
    if (id != null &&
        grupoId != null && grupoId.isNotEmpty &&
        empresaId != null && empresaId.isNotEmpty &&
        centroId != null && centroId.isNotEmpty) {
      try {
        final doc = await FirebaseService.getCasoById(grupoId, empresaId, centroId, id);
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
            _casoData = data;
            try {
              _casoObjeto = Case.fromMap(data);
            } catch (_) {
              _casoObjeto = null;
            }
          });
          }
        }
      } catch (_) {
        // Fallback: usar casoData pasado por navegación si existe
        if (widget.casoData != null && mounted) {
          setState(() {
            _casoData = widget.casoData;
            try {
              _casoObjeto = Case.fromMap(widget.casoData!);
            } catch (_) {
              _casoObjeto = null;
            }
          });
        }
      }
    } else if (widget.casoData != null) {
      if (mounted) {
        setState(() {
        _casoData = widget.casoData;
        try {
          _casoObjeto = Case.fromMap(widget.casoData!);
        } catch (_) {
          _casoObjeto = null;
        }
      });
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// Muestra advertencias del PDF (fotos/firmas que no se pudieron cargar).
  void _mostrarAdvertencias(List<String> advertencias) {
    if (advertencias.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF generado. Nota: ${advertencias.join(", ")}'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Pre-construye el PDF (descarga imágenes/firmas) y lo guarda en caché.
  /// Si ya existe caché, lo reutiliza directamente.
  Future<bool> _asegurarPdfListo() async {
    if (_pdfBytes != null) return true;                   // ya compilado
    if (_casoData == null) return false;

    setState(() => _isPreparing = true);
    try {
      final result = await PdfService.buildPdfBytes(_casoObjeto, _casoData!);
      if (mounted) {
        setState(() {
          _pdfBytes      = result.bytes;
          _pdfNombre     = result.nombre;
          _advertencias  = result.advertencias;
          _isPreparing   = false;
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _isPreparing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparando PDF: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  Future<void> _handleGenerarReporte() async {
    if (_isGenerating || _isSharing || _isPreparing) return;
    final listo = await _asegurarPdfListo();
    if (!listo || !mounted) return;

    setState(() => _isGenerating = true);
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => _pdfBytes!,
        name: _pdfNombre ?? 'Reporte.pdf',
      );
      if (mounted) _mostrarAdvertencias(_advertencias);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generando PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleCompartir() async {
    if (_isGenerating || _isSharing || _isPreparing) return;
    final listo = await _asegurarPdfListo();
    if (!listo || !mounted) return;

    setState(() => _isSharing = true);
    try {
      await Printing.sharePdf(
        bytes: _pdfBytes!,
        filename: _pdfNombre ?? 'Reporte.pdf',
      );
      if (mounted) _mostrarAdvertencias(_advertencias);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCerrado = _casoData?['cerrado'] == true;
    final bool ocupado = _isGenerating || _isSharing || _isPreparing;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Exportar Reporte PDF"),
        backgroundColor: AppColors.pdfAppBar,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ── Contenido principal ──────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // ── Tarjeta de información del caso ───────────────
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                isCerrado ? Icons.task_alt : Icons.warning_amber_rounded,
                                size: 60,
                                color: isCerrado ? AppColors.success : AppColors.warning,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _casoData?['nombre'] ?? "Sin nombre",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const Divider(),
                              _rowInfo("Empresa:", _casoData?['empresaNombre'] ?? "N/A"),
                              _rowInfo("Estado:", isCerrado ? "Cerrado" : "Abierto"),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Indicador de estado del PDF ───────────────────
                      _buildEstadoPdf(),

                      const Spacer(),

                      // ── Botón: Ver / Imprimir PDF ─────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: ocupado ? null : _handleGenerarReporte,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(_isGenerating ? "ABRIENDO..." : "VER / IMPRIMIR PDF"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pdfButton,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Botón: Compartir (WhatsApp, correo, Drive…) ───
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: ocupado ? null : _handleCompartir,
                          icon: _isSharing
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.share),
                          label: Text(_isSharing ? "PREPARANDO..." : "COMPARTIR PDF"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.shareButton,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // ── Overlay de preparación ────────────────────────────
                if (_isPreparing)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              CircularProgressIndicator(),
                              SizedBox(height: 20),
                              Text(
                                "Preparando PDF…",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "Cargando fotos y firmas",
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  /// Pequeño widget que muestra el estado actual del PDF cacheado.
  Widget _buildEstadoPdf() {
    if (_isPreparing) return const SizedBox.shrink();

    if (_pdfBytes != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "PDF listo · toca un botón para ver o compartir",
                style: TextStyle(fontSize: 13, color: Colors.green.shade800),
              ),
            ),
            // Botón para regenerar si el usuario quiere refrescar
            GestureDetector(
              onTap: () => setState(() { _pdfBytes = null; _pdfNombre = null; _advertencias = []; }),
              child: Icon(Icons.refresh, size: 18, color: Colors.green.shade600),
            ),
          ],
        ),
      );
    }

    // Aún no preparado — invita al usuario a pulsar un botón
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Toca un botón para preparar el PDF con fotos y firmas",
              style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowInfo(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}