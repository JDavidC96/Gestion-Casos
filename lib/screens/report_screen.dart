// lib/screens/report_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';

class ReportScreen extends StatefulWidget {
  final String? casoId;

  const ReportScreen({super.key, this.casoId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _isGenerating = false;
  Map<String, dynamic>? _casoData;
  String? _casoId;
  String? _grupoNombre;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Usar el casoId del constructor o cargarlo después
    _casoId = widget.casoId;
    _initializeData();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGrupoInfo();
      _loadCasoData();
    });
  }

  void _loadGrupoInfo() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _grupoNombre = authProvider.grupoNombre;
    });
  }

  Future<void> _loadCasoData() async {
    // Si no tenemos casoId del constructor, intentar obtenerlo de los argumentos de ruta
    if (_casoId == null) {
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs is Map) {
        _casoId = routeArgs['casoId'] as String?;
      }
    }

    if (_casoId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseService.getCasoById(_casoId!);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _casoData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando caso: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getNivelPeligroColor(String nivel) {
    switch (nivel.toLowerCase()) {
      case 'bajo': return 'Verde';
      case 'medio': return 'Amarillo';
      case 'alto': return 'Rojo';
      default: return 'Gris';
    }
  }

  String _getTiempoAccion(String nivel) {
    switch (nivel.toLowerCase()) {
      case 'bajo': return 'Un mes';
      case 'medio': return 'Una semana';
      case 'alto': return 'De inmediato';
      default: return 'No aplica';
    }
  }

  Future<void> _generarExcel() async {
    if (_casoData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos del caso para generar reporte')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Crear archivo Excel
      final excel = Excel.createExcel();
      final sheet = excel['Hoja1'];

      // Título principal
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('I1'));
      sheet.cell(CellIndex.indexByString('A1')).value = 'Proceso Operativo - Registro de Inspecciones';

      // Información General
      sheet.cell(CellIndex.indexByString('A3')).value = '1. Información General';
      sheet.cell(CellIndex.indexByString('A4')).value = 'Empresa';
      sheet.cell(CellIndex.indexByString('E4')).value = _casoData?['empresaNombre'] ?? _grupoNombre ?? 'No especificado';
      sheet.cell(CellIndex.indexByString('F4')).value = 'NIT';
      
      sheet.cell(CellIndex.indexByString('A5')).value = 'Fecha';
      sheet.cell(CellIndex.indexByString('E5')).value = DateTime.now().toString().split(' ')[0];
      sheet.cell(CellIndex.indexByString('F5')).value = 'Hora';
      sheet.cell(CellIndex.indexByString('G5')).value = '${DateTime.now().hour}:${DateTime.now().minute}';
      
      sheet.cell(CellIndex.indexByString('A6')).value = 'Centro de trabajo';
      sheet.cell(CellIndex.indexByString('E6')).value = _casoData?['empresaNombre'] ?? _grupoNombre ?? 'No especificado';
      sheet.cell(CellIndex.indexByString('F6')).value = 'Inspector';
      sheet.cell(CellIndex.indexByString('G6')).value = 'Sistema';

      // Sección de registro de peligros
      sheet.cell(CellIndex.indexByString('A8')).value = '2. Registro de peligros, valoración y control';
      
      // Leyenda de consecuencias
      sheet.merge(CellIndex.indexByString('A9'), CellIndex.indexByString('I9'));
      sheet.cell(CellIndex.indexByString('A9')).value = 'Consecuencia';
      
      sheet.merge(CellIndex.indexByString('A10'), CellIndex.indexByString('I10'));
      sheet.cell(CellIndex.indexByString('A10')).value = 
          'Verde - Bajo: Lesión sin incapacidad\n'
          'Amarillo - Medio: Lesión con incapacidad\n'
          'Rojo - Alto: Enfermedad Laboral, Incapacidad Permanente Parcial, Invalidez o muerte\n'
          'Gris - No aplica';

      // Tabla de tiempos
      sheet.cell(CellIndex.indexByString('G11')).value = 'Grado de riesgo';
      sheet.cell(CellIndex.indexByString('I11')).value = 'Tiempo';
      
      sheet.cell(CellIndex.indexByString('G12')).value = 'Verde';
      sheet.cell(CellIndex.indexByString('I12')).value = 'Un mes';
      
      sheet.cell(CellIndex.indexByString('G14')).value = 'Amarillo';
      sheet.cell(CellIndex.indexByString('I14')).value = 'Una semana';
      
      sheet.cell(CellIndex.indexByString('G16')).value = 'Rojo';
      sheet.cell(CellIndex.indexByString('I16')).value = 'De inmediato';

      // Encabezados de la tabla principal
      final headers = [
        'Ubicación', 'Descripcion del hallazgo', 'Valor Peligro', 
        'Recomendaciones de control', 'Imagen'
      ];
      
      int startRow = 18;
      
      // Escribir encabezados
      sheet.cell(CellIndex.indexByString('A$startRow')).value = headers[0];
      sheet.cell(CellIndex.indexByString('C$startRow')).value = headers[1];
      sheet.cell(CellIndex.indexByString('E$startRow')).value = headers[2];
      sheet.cell(CellIndex.indexByString('G$startRow')).value = headers[3];
      sheet.cell(CellIndex.indexByString('I$startRow')).value = headers[4];

      // Datos del caso específico
      int currentRow = startRow + 1;
      
      final estadoAbierto = _casoData?['estadoAbierto'] as Map<String, dynamic>? ?? {};
      final estadoCerrado = _casoData?['estadoCerrado'] as Map<String, dynamic>? ?? {};
      
      final ubicacion = estadoAbierto['ubicacionTexto'] ?? 'No especificada';
      final descripcionHallazgo = estadoAbierto['descripcionHallazgo'] ?? 'Sin descripción';
      final nivelPeligro = estadoAbierto['nivelPeligro'] ?? 'No especificado';
      final recomendaciones = estadoAbierto['recomendacionesControl'] ?? 'No especificadas';
      final fotoUrl = estadoAbierto['fotoUrl'];

      // Ubicación
      sheet.cell(CellIndex.indexByString('A$currentRow')).value = ubicacion;
      
      // Descripción del hallazgo
      sheet.cell(CellIndex.indexByString('C$currentRow')).value = descripcionHallazgo;
      
      // Valor Peligro (color + nivel)
      final colorPeligro = _getNivelPeligroColor(nivelPeligro);
      final tiempoAccion = _getTiempoAccion(nivelPeligro);
      sheet.cell(CellIndex.indexByString('E$currentRow')).value = '$colorPeligro - $nivelPeligro\nTiempo: $tiempoAccion';
      
      // Recomendaciones de control
      sheet.cell(CellIndex.indexByString('G$currentRow')).value = recomendaciones;
      
      // IMAGEN - Mostrar URL o texto
      if (fotoUrl != null && fotoUrl is String && fotoUrl.startsWith('http')) {
        sheet.cell(CellIndex.indexByString('I$currentRow')).value = 'Imagen disponible\n(${fotoUrl.substring(0, 30)}...)';
      } else {
        sheet.cell(CellIndex.indexByString('I$currentRow')).value = fotoUrl?.toString() ?? 'Sin imagen';
      }

      currentRow++;
      
      // Agregar información de cierre si existe
      if (estadoCerrado['guardado'] == true) {
        final descripcionSolucion = estadoCerrado['descripcionSolucion'] ?? '';
        final fotoCerradoUrl = estadoCerrado['fotoUrl'];
        
        sheet.cell(CellIndex.indexByString('A$currentRow')).value = 'CIERRE - $ubicacion';
        sheet.cell(CellIndex.indexByString('C$currentRow')).value = 'Solución: $descripcionSolucion';
        sheet.cell(CellIndex.indexByString('E$currentRow')).value = 'CERRADO';
        sheet.cell(CellIndex.indexByString('G$currentRow')).value = 'Completado';
        
        // IMAGEN DE CIERRE
        if (fotoCerradoUrl != null && fotoCerradoUrl is String && fotoCerradoUrl.startsWith('http')) {
          sheet.cell(CellIndex.indexByString('I$currentRow')).value = 'Imagen cierre disponible\n(${fotoCerradoUrl.substring(0, 30)}...)';
        } else {
          sheet.cell(CellIndex.indexByString('I$currentRow')).value = fotoCerradoUrl?.toString() ?? 'Sin imagen cierre';
        }
        
        currentRow++;
      }

      // Ajustar anchos de columnas
      sheet.setColumnWidth(0, 20); // Columna A
      sheet.setColumnWidth(2, 30); // Columna C
      sheet.setColumnWidth(4, 25); // Columna E
      sheet.setColumnWidth(6, 30); // Columna G
      sheet.setColumnWidth(8, 20); // Columna I
      // Guardar archivo
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Reporte_Caso_${_casoData?['nombre'] ?? _casoId}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      setState(() => _isGenerating = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Reporte generado para el caso: ${_casoData?['nombre'] ?? "Caso actual"}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Abrir el archivo
        await OpenFile.open(filePath);
      }

    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generando reporte: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Reporte de Inspección"),
          backgroundColor: const Color(0xFF4F81BD),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final casoNombre = _casoData?['nombre'] ?? "Caso actual";
    final empresaNombre = _casoData?['empresaNombre'] ?? _grupoNombre ?? "Sin empresa";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reporte de Inspección"),
        backgroundColor: const Color(0xFF4F81BD),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumen del caso específico
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.assignment, size: 60, color: Color(0xFF4F81BD)),
                      const SizedBox(height: 16),
                      const Text(
                        "Reporte Individual",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F81BD),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Caso: $casoNombre",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Empresa: $empresaNombre",
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Este reporte generará un archivo Excel con el formato oficial de registro de inspecciones para este caso específico.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Información del estado del caso
              if (_casoData != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Estado del Caso",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatCard(
                              'Estado', 
                              _casoData?['cerrado'] == true ? 'Cerrado' : 'Abierto',
                              _casoData?['cerrado'] == true ? Colors.green : Colors.orange
                            ),
                            _buildStatCard(
                              'Fecha', 
                              _formatDate(_casoData?['fechaCreacion']),
                              Colors.blue
                            ),
                          ],
                        ),
                        if (_casoData?['cerrado'] == true) ...[
                          const SizedBox(height: 12),
                          _buildStatCard(
                            'Cierre', 
                            _formatDate(_casoData?['fechaCierre']),
                            Colors.purple
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              const Spacer(),
              
              // Botón de generar reporte
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                child: _isGenerating
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _generarExcel,
                        icon: const Icon(Icons.file_download, size: 24),
                        label: const Text(
                          "Generar Reporte Excel",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'No especificada';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'No especificada';
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}