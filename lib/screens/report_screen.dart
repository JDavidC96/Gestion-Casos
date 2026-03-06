// lib/screens/report_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../models/case_model.dart';
import '../services/pdf_service.dart';

class ReportScreen extends StatefulWidget {
  final String? casoId;
  const ReportScreen({super.key, this.casoId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _isGenerating = false;
  Map<String, dynamic>? _casoData;
  Case? _casoObjeto;
  String? _grupoNombre;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Usamos addPostFrameCallback para asegurar que el contexto esté listo
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _grupoNombre = auth.grupoNombre;
    
    String? id = widget.casoId;
    if (id == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      id = args?['casoId'];
    }

    if (id != null) {
      try {
        final doc = await FirebaseService.getCasoById(id);
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _casoData = data;
            // Manejo de error manual al crear el modelo para evitar que el loader sea infinito
            try {
              _casoObjeto = Case.fromMap(data);
            } catch (e) {
              print("Error al mapear Case: $e");
              // Si falla el modelo, creamos uno básico para no bloquear la app
              _casoObjeto = null; 
            }
          });
        }
      } catch (e) {
        print("Error cargando de Firebase: $e");
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGenerarReporte() async {
    // Si el objeto Case falló, usamos los datos crudos del mapa
    if (_casoData == null) return;
    
    setState(() => _isGenerating = true);
    try {
      // Pasamos tanto el objeto (si existe) como el mapa para mayor seguridad
      await PdfService.generarReportePDF(_casoObjeto, _casoData!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF generado con éxito'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error detallado PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCerrado = _casoData?['cerrado'] == true;
    
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
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(isCerrado ? Icons.task_alt : Icons.warning_amber_rounded, 
                             size: 60, color: isCerrado ? Colors.green : Colors.orange),
                        const SizedBox(height: 10),
                        Text(_casoData?['nombre'] ?? "Sin nombre", 
                             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _rowInfo("Empresa:", _casoData?['empresaNombre'] ?? "N/A"),
                        _rowInfo("Estado:", isCerrado ? "Cerrado" : "Abierto"),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _handleGenerarReporte,
                    icon: _isGenerating 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_isGenerating ? "GENERANDO..." : "GENERAR PDF"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
              ],
            ),
          ),
    );
  }

  Widget _rowInfo(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(val, style: const TextStyle(fontWeight: FontWeight.bold))],
    ),
  );
}