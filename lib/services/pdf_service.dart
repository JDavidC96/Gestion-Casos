import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/case_model.dart';

class PdfService {
  static String? _convertirUrlDrive(String? url) {
    if (url == null) return null;
    if (url.contains("drive.google.com")) {
      final String? fileId = RegExp(r'\/d\/([a-zA-Z0-9-_]+)').firstMatch(url)?.group(1);
      if (fileId != null) return "https://drive.google.com/uc?export=download&id=$fileId";
    }
    return url;
  }

  // Mantenemos la firma original para no romper ReportScreen
  static Future<void> generarReportePDF(Case? caso, Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    // --- EXTRACCIÓN "INTELIGENTE" ---
    // Si el campo en el objeto 'caso' está vacío o es 'N/A', lo toma del mapa 'data'
    
    final String nombreCaso = _obtenerValor(caso?.nombre, data['nombre']) ?? 'Sin Nombre';
    final String categoria = _obtenerValor(caso?.tipoRiesgo, data['tipoRiesgo']) ?? 'N/A';
    final String tipoEspecifico = _obtenerValor(caso?.subgrupoRiesgo, data['subgrupoRiesgo']) ?? 'N/A';
    final String empresa = _obtenerValor(caso?.empresaNombre, data['empresaNombre']) ?? 'N/A';
    final String centro = _obtenerValor(caso?.centroNombre, data['centroNombre']) ?? 'Principal';

    // Manejo de datos del hallazgo (dentro de estadoAbierto)
    final Map<String, dynamic> estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};
    
    // El nivel de riesgo suele estar en el detalle del hallazgo
    final String nivelRiesgo = _obtenerValor(caso?.nivelPeligro, estadoAbierto['nivelPeligro']) ?? data['nivelPeligro'] ?? 'N/A';
    final String inspector = _obtenerValor(caso?.usuarioNombre, estadoAbierto['usuarioNombre']) ?? data['usuarioNombre'] ?? 'N/A';
    final String ubicacion = estadoAbierto['ubicacionTexto'] ?? 'N/A';
    final String descHallazgo = estadoAbierto['descripcionHallazgo'] ?? data['descripcionRiesgo'] ?? 'Sin descripción';
    final String control = estadoAbierto['recomendacionesControl'] ?? 'N/A';

    // Fecha
    DateTime fechaC;
    if (data['fechaCreacion'] is Timestamp) {
      fechaC = (data['fechaCreacion'] as Timestamp).toDate();
    } else {
      fechaC = caso?.fechaCreacion ?? DateTime.now();
    }
    
    final String fechaTexto = DateFormat('dd/MM/yyyy').format(fechaC);
    final String horaTexto = DateFormat('HH:mm:ss').format(fechaC);

    // Imagen
    pw.MemoryImage? imageHallazgo;
    String? directUrl = _convertirUrlDrive(estadoAbierto['fotoUrl']);
    if (directUrl != null) {
      try {
        final response = await http.get(Uri.parse(directUrl)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) imageHallazgo = pw.MemoryImage(response.bodyBytes);
      } catch (e) { print("Error cargando imagen: $e"); }
    }

    // ... (El resto del diseño del PDF se mantiene igual que el anterior)
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            _buildHeader(),
            _tituloSeccion("1. Información General"),
            _buildInfoTable(empresa, fechaTexto, horaTexto, centro, inspector),
            _tituloSeccion("2. Detalle del Hallazgo"),
            _buildDataTable(nombreCaso, categoria, tipoEspecifico, ubicacion, descHallazgo, nivelRiesgo, control, imageHallazgo),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: "Reporte_$nombreCaso.pdf");
  }

  // FUNCIÓN CLAVE: Valida si el objeto tiene el dato, si no, usa el del mapa
  static String? _obtenerValor(String? objetoVal, dynamic mapaVal) {
    if (objetoVal != null && objetoVal.isNotEmpty && objetoVal != 'N/A' && objetoVal != 'null') {
      return objetoVal;
    }
    if (mapaVal != null && mapaVal.toString().isNotEmpty) {
      return mapaVal.toString();
    }
    return null;
  }

  // --- MÉTODOS DE APOYO PARA EL DISEÑO ---
  static pw.Widget _buildHeader() => pw.Table(
    border: pw.TableBorder.all(),
    children: [
      pw.TableRow(children: [
        pw.Container(height: 40, child: pw.Center(child: pw.Text("LOGO"))),
        pw.Container(height: 40, child: pw.Center(child: pw.Text("REGISTRO DE INSPECCIÓN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
        pw.Container(height: 40, child: pw.Center(child: pw.Text("v.01", style: const pw.TextStyle(fontSize: 8)))),
      ])
    ]
  );

  static pw.Widget _buildInfoTable(String e, String f, String h, String c, String i) => pw.Table(
    border: pw.TableBorder.all(),
    children: [
      _filaInfo("Empresa", e, "Fecha", f),
      _filaInfo("Centro", c, "Hora", h),
      _filaInfo("Inspector", i, "", ""),
    ]
  );

  static pw.Widget _buildDataTable(String n, String cat, String tip, String ubi, String desc, String niv, String con, pw.MemoryImage? img) => pw.Table(
    border: pw.TableBorder.all(),
    columnWidths: {4: const pw.FlexColumnWidth(2), 7: const pw.FixedColumnWidth(100)},
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: ["Caso", "Categoría", "Tipo", "Ubicación", "Descripción", "Riesgo", "Control", "Evidencia"].map((t) => _celdaHeader(t)).toList()
      ),
      pw.TableRow(
        children: [
          _celdaData(n), _celdaData(cat), _celdaData(tip), _celdaData(ubi), _celdaData(desc), _celdaData(niv), _celdaData(con),
          pw.Container(height: 80, child: img != null ? pw.Image(img) : pw.Center(child: pw.Text("Sin foto", style: const pw.TextStyle(fontSize: 6))))
        ]
      )
    ]
  );

  static pw.Widget _tituloSeccion(String t) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)));
  static pw.TableRow _filaInfo(String l1, String v1, String l2, String v2) => pw.TableRow(children: [
    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("$l1: $v1", style: const pw.TextStyle(fontSize: 8))),
    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("$l2: $v2", style: const pw.TextStyle(fontSize: 8))),
  ]);
  static pw.Widget _celdaHeader(String t) => pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)));
  static pw.Widget _celdaData(String t) => pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)));
}