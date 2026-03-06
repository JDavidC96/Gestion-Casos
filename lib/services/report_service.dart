// lib/services/report_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportService {
  
  // Generar reporte de casos con filtros
  static Future<void> generarReporteCasosPDF({
    required List<QueryDocumentSnapshot> casos,
    required DateTime fecha,
    String? supervisor,
    bool incluirCerrados = true,
    required String empresaNombre,
    String? centroNombre,
  }) async {
    
    final pdf = pw.Document();
    final casosFiltrados = _filtrarCasosPorDia(
      casos: casos,
      fecha: fecha,
      supervisor: supervisor,
      incluirCerrados: incluirCerrados,
    );

    if (casosFiltrados.isEmpty) {
      throw Exception('No hay casos para el día seleccionado');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            _buildHeader(empresaNombre, centroNombre, fecha, supervisor),
            pw.SizedBox(height: 20),
            _buildTablaCasos(casosFiltrados),
            _buildResumen(casosFiltrados),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Reporte_Casos_${DateFormat('yyyyMMdd').format(fecha)}.pdf',
    );
  }

  // Generar reporte mensual por centros de trabajo (formato imagen)
  static Future<void> generarReporteMensualCentrosPDF({
    required Map<String, List<QueryDocumentSnapshot>> casosPorCentro,
    required int mes,
    required int anio,
    String? supervisor,
    bool incluirCerrados = true,
    required String empresaNombre,
  }) async {
    
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a3.landscape, // Formato más ancho para la tabla
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return [
            _buildHeaderMensual(empresaNombre, mes, anio, supervisor),
            pw.SizedBox(height: 15),
            _buildTablaCentrosFormatoImagen(casosPorCentro, mes, anio),
            _buildResumenMensual(casosPorCentro),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Reporte_Mensual_Centros_${_getNombreMes(mes)}_$anio.pdf',
    );
  }

  static List<QueryDocumentSnapshot> _filtrarCasosPorDia({
    required List<QueryDocumentSnapshot> casos,
    required DateTime fecha,
    String? supervisor,
    required bool incluirCerrados,
  }) {
    final fechaInicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fechaFin = fechaInicio.add(const Duration(days: 1));

    return casos.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Filtrar por fecha
      final fechaCreacion = (data['fechaCreacion'] as Timestamp?)?.toDate();
      if (fechaCreacion == null) return false;
      
      final dentroDeFecha = fechaCreacion.isAfter(fechaInicio) && 
                           fechaCreacion.isBefore(fechaFin);
      if (!dentroDeFecha) return false;

      // Filtrar por supervisor si se especificó
      if (supervisor != null && supervisor.isNotEmpty) {
        final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>?;
        final usuarioNombre = estadoAbierto?['usuarioNombre'] ?? data['usuarioNombre'];
        if (usuarioNombre != supervisor) return false;
      }

      // Filtrar por estado si no se incluyen cerrados
      if (!incluirCerrados && data['cerrado'] == true) return false;

      return true;
    }).toList();
  }

  static pw.Widget _buildHeader(String empresa, String? centro, DateTime fecha, String? supervisor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('REPORTE DIARIO DE CASOS', 
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}',
                style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Empresa: $empresa'),
              if (centro != null) pw.Text('Centro: $centro'),
              if (supervisor != null && supervisor.isNotEmpty) 
                pw.Text('Supervisor: $supervisor'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTablaCasos(List<QueryDocumentSnapshot> casos) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Hora
        1: const pw.FlexColumnWidth(3), // Inspector
        2: const pw.FlexColumnWidth(3), // Centro
        3: const pw.FlexColumnWidth(3), // Ubicación
        4: const pw.FlexColumnWidth(5), // Descripción
        5: const pw.FlexColumnWidth(2), // Riesgo
        6: const pw.FlexColumnWidth(2), // Estado
      },
      children: [
        // Encabezados
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _celdaHeader('Hora'),
            _celdaHeader('Inspector'),
            _celdaHeader('Centro'),
            _celdaHeader('Ubicación'),
            _celdaHeader('Descripción'),
            _celdaHeader('Riesgo'),
            _celdaHeader('Estado'),
          ],
        ),
        // Datos
        ...casos.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};
          final fecha = (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now();
          
          return pw.TableRow(
            children: [
              _celdaData(DateFormat('HH:mm').format(fecha)),
              _celdaData(estadoAbierto['usuarioNombre'] ?? data['usuarioNombre'] ?? 'N/A'),
              _celdaData(data['centroNombre'] ?? 'N/A'),
              _celdaData(estadoAbierto['ubicacionTexto'] ?? 'N/A'),
              _celdaData(estadoAbierto['descripcionHallazgo'] ?? data['descripcionRiesgo'] ?? 'N/A', maxLength: 50),
              _celdaData(estadoAbierto['nivelPeligro'] ?? data['nivelPeligro'] ?? 'N/A'),
              _celdaData(data['cerrado'] == true ? 'Cerrado' : 'Abierto'),
            ],
          );
        }),
      ],
    );
  }

  // Tabla con formato exacto de la imagen
  static pw.Widget _buildTablaCentrosFormatoImagen(
    Map<String, List<QueryDocumentSnapshot>> casosPorCentro,
    int mes,
    int anio,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // FECHA
        1: const pw.FlexColumnWidth(3), // INSPECTOR
        2: const pw.FlexColumnWidth(2.5), // CENTRO DE TRABAJO
        3: const pw.FlexColumnWidth(2.5), // UBICACIÓN ESPECÍFICA
        4: const pw.FlexColumnWidth(4), // DESCRIPCIÓN PELIGRO GRADO RIESGO CONTROL
        5: const pw.FlexColumnWidth(3), // CONTROL ESPECÍFICO ESTADO DEL CONTROL
      },
      children: [
        // Encabezados exactos como en la imagen
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _celdaHeader('FECHA', fontSize: 8),
            _celdaHeader('INSPECTOR', fontSize: 8),
            _celdaHeader('CENTRO DE TRABAJO', fontSize: 8),
            _celdaHeader('UBICACIÓN ESPECÍFICA', fontSize: 8),
            _celdaHeader('DESCRIPCIÓN PELIGRO GRADO RIESGO CONTROL', fontSize: 8),
            _celdaHeader('CONTROL ESPECÍFICO ESTADO DEL CONTROL', fontSize: 8),
          ],
        ),
        // Datos
        ...casosPorCentro.entries.expand((entry) {
          final centroNombre = entry.key;
          return entry.value.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};
            final fecha = (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now();
            
            final descripcionCompleta = '${estadoAbierto['descripcionHallazgo'] ?? data['descripcionRiesgo'] ?? 'Sin hallazgos'} '
                '${estadoAbierto['nivelPeligro'] ?? data['nivelPeligro'] ?? '16'} '
                '${data['cerrado'] == true ? 'Cerrado' : 'Pendiente'}';
            
            final controlCompleto = '${estadoAbierto['recomendacionesControl'] ?? 'No Aplica'} '
                '${data['cerrado'] == true ? 'Cerrado' : 'Pendiente'}';
            
            return pw.TableRow(
              children: [
                _celdaData(DateFormat('dd/MM/yyyy HH:mm').format(fecha), fontSize: 7),
                _celdaData(estadoAbierto['usuarioNombre'] ?? data['usuarioNombre'] ?? 'N/A', fontSize: 7),
                _celdaData(centroNombre, fontSize: 7),
                _celdaData(estadoAbierto['ubicacionTexto'] ?? 'N/A', fontSize: 7),
                _celdaData(descripcionCompleta, fontSize: 7, maxLength: 60),
                _celdaData(controlCompleto, fontSize: 7, maxLength: 50),
              ],
            );
          });
        }),
      ],
    );
  }

  static pw.Widget _buildResumen(List<QueryDocumentSnapshot> casos) {
    final totalCasos = casos.length;
    final abiertos = casos.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['cerrado'] != true;
    }).length;
    final cerrados = totalCasos - abiertos;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('RESUMEN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text('Total casos: $totalCasos'),
          pw.Text('Abiertos: $abiertos'),
          pw.Text('Cerrados: $cerrados'),
        ],
      ),
    );
  }

  static pw.Widget _buildResumenMensual(Map<String, List<QueryDocumentSnapshot>> casosPorCentro) {
    int totalCasos = 0;
    casosPorCentro.forEach((_, casos) => totalCasos += casos.length);
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('RESUMEN MENSUAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text('Total centros: ${casosPorCentro.length}'),
          pw.Text('Total casos: $totalCasos'),
          ...casosPorCentro.entries.map((e) => 
            pw.Text('• ${e.key}: ${e.value.length} casos')
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderMensual(String empresa, int mes, int anio, String? supervisor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('REPORTE MENSUAL DE CASOS POR CENTRO DE TRABAJO',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text('Período: ${_getNombreMes(mes)} $anio'),
        pw.Text('Empresa: $empresa'),
        if (supervisor != null && supervisor.isNotEmpty) 
          pw.Text('Supervisor: $supervisor'),
        pw.Text('Fecha generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
        pw.SizedBox(height: 10),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _celdaHeader(String texto, {double fontSize = 9}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        texto,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _celdaData(String texto, {double fontSize = 8, int? maxLength}) {
    String displayText = texto;
    if (maxLength != null && displayText.length > maxLength) {
      displayText = '${displayText.substring(0, maxLength)}...';
    }
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        displayText,
        style: pw.TextStyle(fontSize: fontSize),
      ),
    );
  }

  static String _getNombreMes(int mes) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return meses[mes - 1];
  }
}