// lib/screens/report_screen.dart
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/case_model.dart';
import '../services/pdf_service.dart';

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
    // para garantizar que estadoAbierto.firmaClienteUrl esté presente
    if (id != null &&
        grupoId != null && grupoId.isNotEmpty &&
        empresaId != null && empresaId.isNotEmpty &&
        centroId != null && centroId.isNotEmpty) {
      try {
        final doc = await FirebaseService.getCasoById(grupoId, empresaId, centroId, id);
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (mounted) setState(() {
            _casoData = data;
            try {
              _casoObjeto = Case.fromMap(data);
            } catch (e) {
              print("Error al mapear Case: $e");
              _casoObjeto = null;
            }
          });
        }
      } catch (e) {
        print("Error cargando de Firebase: $e");
        // Fallback: usar casoData pasado por navegación si existe
        if (widget.casoData != null && mounted) {
          setState(() {
            _casoData = widget.casoData;
            try {
              _casoObjeto = Case.fromMap(widget.casoData!);
            } catch (e) {
              _casoObjeto = null;
            }
          });
        }
      }
    } else if (widget.casoData != null) {
      // Sin IDs completos, usar lo que llegó por navegación
      if (mounted) setState(() {
        _casoData = widget.casoData;
        try {
          _casoObjeto = Case.fromMap(widget.casoData!);
        } catch (e) {
          print("Error al mapear Case: $e");
          _casoObjeto = null;
        }
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleGenerarReporte() async {
    if (_casoData == null) return;
    setState(() => _isGenerating = true);
    try {
      await PdfService.generarReportePDF(_casoObjeto, _casoData!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF generado con éxito'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleCompartir() async {
    if (_casoData == null) return;
    setState(() => _isSharing = true);
    try {
      await PdfService.compartirReportePDF(_casoObjeto, _casoData!);
    } catch (e) {
      print("Error compartiendo PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al compartir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCerrado = _casoData?['cerrado'] == true;
    final bool ocupado = _isGenerating || _isSharing;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Exportar Reporte PDF"),
        backgroundColor: const Color(0xFF4F81BD),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Tarjeta de información del caso ──────────────
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
                            color: isCerrado ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _casoData?['nombre'] ?? "Sin nombre",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(),
                          _rowInfo("Empresa:", _casoData?['empresaNombre'] ?? "N/A"),
                          _rowInfo("Estado:", isCerrado ? "Cerrado ✓" : "Abierto"),
                        ],
                      ),
                    ),
                  ),

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
                      label: Text(_isGenerating ? "GENERANDO..." : "VER / IMPRIMIR PDF"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
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
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
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