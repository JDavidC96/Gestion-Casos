import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';

class ExcelService {
  static Future<String> generarReporteInspeccion(Map<String, dynamic> casoData, String grupoNombre) async {
    // 1. Crear el Workbook
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    
    // --- ESTILOS ---
    final Style headerStyle = workbook.styles.add('headerStyle');
    headerStyle.backColor = '#4F81BD';
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.bold = true;
    headerStyle.vAlign = VAlignType.center;
    headerStyle.hAlign = HAlignType.center;
    headerStyle.borders.all.lineStyle = LineStyle.thin;

    // --- DISEÑO DE CABECERA ---
    sheet.getRangeByName('A1:I1').merge();
    final Range titleRange = sheet.getRangeByName('A1');
    titleRange.setText('Proceso Operativo - Registro de Inspecciones');
    titleRange.cellStyle = headerStyle;
    sheet.setRowHeightInPixels(1, 40);

    // --- INFORMACIÓN GENERAL ---
    sheet.getRangeByName('A3').setText('1. Información General');
    sheet.getRangeByName('A3').cellStyle.bold = true;
    
    _escribirCampo(sheet, 4, 'Empresa', casoData['empresaNombre'] ?? grupoNombre);
    _escribirCampo(sheet, 5, 'Fecha', DateTime.now().toString().split(' ')[0]);
    _escribirCampo(sheet, 6, 'Inspector', 'Sistema de Gestión');

    // --- TABLA DE HALLAZGOS ---
    int row = 10;
    _crearEncabezadosTabla(sheet, row, headerStyle);
    
    row++;
    // Fila de Apertura
    await _insertarFilaHallazgo(sheet, row, casoData['estadoAbierto'], "APERTURA");

    // Fila de Cierre (si existe)
    if (casoData['cerrado'] == true && casoData['estadoCerrado'] != null) {
      row++;
      await _insertarFilaHallazgo(sheet, row, casoData['estadoCerrado'], "CIERRE");
    }

    // --- GUARDADO ---
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Reporte_${casoData['nombre']}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  static void _escribirCampo(Worksheet sheet, int row, String label, String value) {
    sheet.getRangeByIndex(row, 1).setText(label);
    sheet.getRangeByIndex(row, 5).setText(value);
  }

  static void _crearEncabezadosTabla(Worksheet sheet, int row, Style style) {
    final headers = ['Ubicación', 'Descripción', 'Valor Peligro', 'Recomendaciones', 'Imagen'];
    final indices = [1, 3, 5, 7, 9];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(row, indices[i]);
      cell.setText(headers[i]);
      cell.cellStyle = style;
      // Ajustar anchos
      sheet.setColumnWidthInPixels(indices[i], 120);
    }
  }

  static Future<void> _insertarFilaHallazgo(Worksheet sheet, int row, Map<String, dynamic>? data, String tipo) async {
    if (data == null) return;

    sheet.getRangeByIndex(row, 1).setText("${tipo}: ${data['ubicacionTexto'] ?? 'N/A'}");
    sheet.getRangeByIndex(row, 3).setText(data['descripcionHallazgo'] ?? data['descripcionSolucion'] ?? '');
    sheet.getRangeByIndex(row, 5).setText(data['nivelPeligro'] ?? 'CERRADO');
    sheet.getRangeByIndex(row, 7).setText(data['recomendacionesControl'] ?? 'Completado');
    
    // Lógica de descarga e inserción de imagen
    String? url = data['fotoUrl'];
    if (url != null && url.toString().startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          sheet.pictures.addStream(row, 9, response.bodyBytes);
          sheet.setRowHeightInPixels(row, 120); // Espacio para que quepa la foto
        }
      } catch (e) {
        sheet.getRangeByIndex(row, 9).setText("Error al cargar imagen");
      }
    }
  }
}