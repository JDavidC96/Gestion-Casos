import 'dart:typed_data';
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

  /// Genera los bytes del PDF sin mostrarlo ni compartirlo.
  /// Usado internamente por [generarReportePDF] y [compartirReportePDF].
  static Future<({Uint8List bytes, String nombre})> _buildPdfBytes(
      Case? caso, Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final String nombreCaso     = _obtenerValor(caso?.nombre,          data['nombre'])          ?? 'Sin Nombre';
    final String categoria      = _obtenerValor(caso?.tipoRiesgo,      data['tipoRiesgo'])      ?? 'N/A';
    final String tipoEspecifico = _obtenerValor(caso?.subgrupoRiesgo,  data['subgrupoRiesgo'])  ?? 'N/A';
    final String empresa        = _obtenerValor(caso?.empresaNombre,   data['empresaNombre'])   ?? 'N/A';
    final String centro         = _obtenerValor(caso?.centroNombre,    data['centroNombre'])    ?? 'Principal';

    final Map<String, dynamic> estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};

    final String nivelRiesgo  = _obtenerValor(caso?.nivelPeligro,   estadoAbierto['nivelPeligro'])   ?? data['nivelPeligro']   ?? 'N/A';
    final String inspector    = _obtenerValor(caso?.usuarioNombre,  estadoAbierto['usuarioNombre'])  ?? data['usuarioNombre']  ?? 'N/A';
    final String ubicacion    = estadoAbierto['ubicacionTexto']         ?? 'N/A';
    final String descHallazgo = estadoAbierto['descripcionHallazgo']    ?? data['descripcionRiesgo'] ?? 'Sin descripción';
    final String control      = estadoAbierto['recomendacionesControl'] ?? 'N/A';

    DateTime fechaC;
    if (data['fechaCreacion'] is Timestamp) {
      fechaC = (data['fechaCreacion'] as Timestamp).toDate();
    } else {
      fechaC = caso?.fechaCreacion ?? DateTime.now();
    }
    final String fechaTexto = DateFormat('dd/MM/yyyy').format(fechaC);
    final String horaTexto  = DateFormat('HH:mm:ss').format(fechaC);

    // ── Cargar imagen del hallazgo ───────────────────────────────────────
    pw.MemoryImage? imageHallazgo;
    final String? directUrl = _convertirUrlDrive(estadoAbierto['fotoUrl']);
    if (directUrl != null) {
      try {
        final response = await http.get(Uri.parse(directUrl)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) imageHallazgo = pw.MemoryImage(response.bodyBytes);
      } catch (e) { print("Error cargando imagen: $e"); }
    }

    // ── Cargar logo del grupo desde Firestore ────────────────────────────
    pw.MemoryImage? imagenLogo;
    final String? grupoId = data['grupoId'] as String?;
    if (grupoId != null) {
      try {
        final grupoDoc = await FirebaseFirestore.instance
            .collection('grupos')
            .doc(grupoId)
            .get();
        final String? logoUrl = _convertirUrlDrive(grupoDoc.data()?['logoUrl'] as String?);
        if (logoUrl != null) {
          final logoResp = await http.get(Uri.parse(logoUrl))
              .timeout(const Duration(seconds: 15));
          if (logoResp.statusCode == 200) {
            imagenLogo = pw.MemoryImage(logoResp.bodyBytes);
          }
        }
      } catch (e) {
        print("Error cargando logo: $e");
      }
    }

    // ── Cargar firma del inspector desde Firestore ───────────────────────
    pw.MemoryImage? imagenFirmaInspector;
    final String? creadoPor = data['creadoPor'] as String?;
    if (creadoPor != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(creadoPor)
            .get();
        final String? firmaUrl = _convertirUrlDrive(userDoc.data()?['firmaUrl'] as String?);
        if (firmaUrl != null) {
          final firmaResp = await http.get(Uri.parse(firmaUrl))
              .timeout(const Duration(seconds: 15));
          if (firmaResp.statusCode == 200) {
            imagenFirmaInspector = pw.MemoryImage(firmaResp.bodyBytes);
          }
        }
      } catch (e) {
        print("Error cargando firma inspector: $e");
      }
    }

    // ── Cargar firma del cliente desde el estado del caso ────────────────
    pw.MemoryImage? imagenFirmaCliente;
    final String? firmaClienteUrl = _convertirUrlDrive(
        estadoAbierto['firmaClienteUrl'] as String?);
    if (firmaClienteUrl != null) {
      try {
        final firmaClienteResp = await http.get(Uri.parse(firmaClienteUrl))
            .timeout(const Duration(seconds: 15));
        if (firmaClienteResp.statusCode == 200) {
          imagenFirmaCliente = pw.MemoryImage(firmaClienteResp.bodyBytes);
        }
      } catch (e) {
        print("Error cargando firma cliente: $e");
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          _buildHeader(imagenLogo),
          _tituloSeccion("1. Información General"),
          _buildInfoTable(empresa, fechaTexto, horaTexto, centro, inspector),
          _tituloSeccion("2. Detalle del Hallazgo"),
          _buildDataTable(nombreCaso, categoria, tipoEspecifico, ubicacion, descHallazgo, nivelRiesgo, control, imageHallazgo),
          pw.SizedBox(height: 20),
          _buildFirmas(inspector, centro, imagenFirmaInspector, imagenFirmaCliente),
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    return (bytes: bytes, nombre: "Reporte_$nombreCaso.pdf");
  }

  /// Abre el visor de impresión/PDF nativo del dispositivo.
  static Future<void> generarReportePDF(Case? caso, Map<String, dynamic> data) async {
    final result = await _buildPdfBytes(caso, data);
    await Printing.layoutPdf(
      onLayout: (_) async => result.bytes,
      name: result.nombre,
    );
  }

  /// Abre el menú nativo de compartir (WhatsApp, correo, Drive, etc.).
  static Future<void> compartirReportePDF(Case? caso, Map<String, dynamic> data) async {
    final result = await _buildPdfBytes(caso, data);
    await Printing.sharePdf(
      bytes: result.bytes,
      filename: result.nombre,
    );
  }

  static String? _obtenerValor(String? objetoVal, dynamic mapaVal) {
    if (objetoVal != null && objetoVal.isNotEmpty && objetoVal != 'N/A' && objetoVal != 'null') {
      return objetoVal;
    }
    if (mapaVal != null && mapaVal.toString().isNotEmpty) {
      return mapaVal.toString();
    }
    return null;
  }

  // ── Header con logo en esquina superior derecha ──────────────────────────
  static pw.Widget _buildHeader([pw.MemoryImage? logo]) => pw.Table(
    border: pw.TableBorder.all(),
    columnWidths: {
      0: const pw.FlexColumnWidth(3),   // título principal — más ancho
      1: const pw.FlexColumnWidth(1),   // versión — estrecho
      2: const pw.FixedColumnWidth(70), // logo — esquina derecha, tamaño fijo
    },
    children: [
      pw.TableRow(children: [
        // Col izq: título
        pw.Container(
          height: 60,
          padding: const pw.EdgeInsets.all(6),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "REGISTRO DE INSPECCIÓN DE SEGURIDAD",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ),
        // Col centro: versión
        pw.Container(
          height: 60,
          child: pw.Center(
            child: pw.Text("v.01", style: const pw.TextStyle(fontSize: 8)),
          ),
        ),
        // Col der: logo (esquina superior derecha)
        pw.Container(
          height: 60,
          padding: const pw.EdgeInsets.all(4),
          child: logo != null
              ? pw.Image(logo, fit: pw.BoxFit.contain)
              : pw.Center(
                  child: pw.Text(
                    "LOGO",
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
                  ),
                ),
        ),
      ])
    ]
  );

  static pw.Widget _buildInfoTable(String e, String f, String h, String c, String i) => pw.Table(
    border: pw.TableBorder.all(),
    children: [
      _filaInfo("Empresa", e, "Fecha", f),
      _filaInfo("Centro",  c, "Hora",  h),
      _filaInfo("Inspector", i, "", ""),
    ]
  );

  static pw.Widget _buildDataTable(String n, String cat, String tip, String ubi, String desc, String niv, String con, pw.MemoryImage? img) => pw.Table(
    border: pw.TableBorder.all(),
    columnWidths: {4: const pw.FlexColumnWidth(2), 7: const pw.FixedColumnWidth(100)},
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: ["Caso", "Categoría", "Tipo", "Ubicación", "Descripción", "Riesgo", "Control", "Evidencia"]
            .map((t) => _celdaHeader(t)).toList(),
      ),
      pw.TableRow(
        children: [
          _celdaData(n), _celdaData(cat), _celdaData(tip), _celdaData(ubi),
          _celdaData(desc), _celdaData(niv), _celdaData(con),
          pw.Container(height: 80, child: img != null
              ? pw.Image(img)
              : pw.Center(child: pw.Text("Sin foto", style: const pw.TextStyle(fontSize: 6)))),
        ],
      ),
    ]
  );

  static pw.Widget _tituloSeccion(String t) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
  );

  static pw.TableRow _filaInfo(String l1, String v1, String l2, String v2) => pw.TableRow(children: [
    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("$l1: $v1", style: const pw.TextStyle(fontSize: 8))),
    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("$l2: $v2", style: const pw.TextStyle(fontSize: 8))),
  ]);

  static pw.Widget _celdaHeader(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(3),
    child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
  );

  static pw.Widget _celdaData(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(3),
    child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)),
  );

  // ── Sección de firmas al pie del reporte ─────────────────────────────────
  static pw.Widget _buildFirmas(String inspectorNombre, String centroNombre,
      [pw.MemoryImage? firmaInspector, pw.MemoryImage? firmaCliente]) =>
      pw.Table(
    border: pw.TableBorder.all(),
    columnWidths: {
      0: const pw.FlexColumnWidth(1),
      1: const pw.FlexColumnWidth(1),
    },
    children: [
      // Fila encabezado
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              "FIRMA DEL INSPECTOR",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              "FIRMA DEL RESPONSABLE / CLIENTE",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
      // Fila imágenes de firma
      pw.TableRow(children: [
        pw.Container(
          height: 50,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Center(
            child: firmaInspector != null
                ? pw.Image(firmaInspector, fit: pw.BoxFit.contain)
                : pw.SizedBox(),
          ),
        ),
        pw.Container(
          height: 50,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Center(
            child: firmaCliente != null
                ? pw.Image(firmaCliente, fit: pw.BoxFit.contain)
                : pw.SizedBox(),
          ),
        ),
      ]),
      // Fila nombre
      pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            inspectorNombre,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            centroNombre,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ]),
    ],
  );
}