import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/case_model.dart';

class PdfService {
  /// Extrae el fileId de cualquier variante de URL de Google Drive.
  static String? _extraerFileIdDrive(String url) {
    // /d/{id}/  ó  id={id}
    return RegExp(r'(?:\/d\/|[?&]id=)([a-zA-Z0-9-_]+)')
        .firstMatch(url)
        ?.group(1);
  }

  /// Descarga una imagen de forma robusta:
  ///  • Si es URL de Drive, intenta primero con el endpoint de thumbnail
  ///    (confiable, sin página de confirmación) y cae a uc?export=download
  ///    si el thumbnail no da una imagen válida.
  ///  • Para cualquier URL, reintenta hasta [reintentos] veces con back-off.
  ///  • Valida que la respuesta sea realmente una imagen (Content-Type image/*).
  ///  • Detecta y maneja la página de confirmación de virus-scan de Drive.
  /// Verifica si los bytes corresponden a una imagen real (PNG o JPEG)
  /// inspeccionando los magic bytes del archivo.
  static bool _esImagenValida(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // JPEG: empieza con FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: empieza con 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // GIF: empieza con 47 49 46
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WebP: empieza con 52 49 46 46 ... 57 45 42 50
    if (bytes.length > 12 && bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) return true;
    return false;
  }

  static Future<Uint8List?> _descargarImagen(String? rawUrl,
      {int reintentos = 3}) async {
    if (rawUrl == null || rawUrl.isEmpty) return null;

    // Construir lista de URLs a intentar en orden
    final List<String> urls = [];
    if (rawUrl.contains('drive.google.com') ||
        rawUrl.contains('docs.google.com')) {
      final String? fileId = _extraerFileIdDrive(rawUrl);
      if (fileId != null) {
        // Thumbnail: sin confirmación, alta disponibilidad, buena resolución
        urls.add('https://drive.google.com/thumbnail?id=$fileId&sz=w1200');
        // Descarga directa como fallback
        urls.add('https://drive.google.com/uc?export=download&id=$fileId');
      }
    }
    // URL original siempre como último recurso
    if (!urls.contains(rawUrl)) urls.add(rawUrl);

    for (final url in urls) {
      for (int intento = 0; intento < reintentos; intento++) {
        try {
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 25));

          if (response.statusCode != 200) continue;

          final contentType = response.headers['content-type'] ?? '';

          // ✅ Respuesta es una imagen por Content-Type — éxito
          if (contentType.startsWith('image/')) {
            return response.bodyBytes;
          }

          // ✅ Drive a veces devuelve application/octet-stream para
          //    archivos recién subidos. Si los bytes son realmente
          //    una imagen (magic bytes), aceptarlos.
          if (contentType.contains('application/octet-stream') &&
              _esImagenValida(response.bodyBytes)) {
            return response.bodyBytes;
          }

          // ⚠️ Drive devolvió página HTML de confirmación de virus-scan
          if (contentType.contains('text/html')) {
            final body = response.body;
            // Extraer el token 'confirm' del formulario de Drive
            final confirmMatch =
                RegExp(r'confirm=([^&"&\s]+)').firstMatch(body);
            if (confirmMatch != null) {
              final confirmUrl =
                  'https://drive.google.com/uc?export=download'
                  '&confirm=${confirmMatch.group(1)}'
                  '&id=${_extraerFileIdDrive(url) ?? ''}';
              final confirmResp = await http
                  .get(Uri.parse(confirmUrl))
                  .timeout(const Duration(seconds: 25));
              if (confirmResp.statusCode == 200) {
                final confirmCt = confirmResp.headers['content-type'] ?? '';
                if (confirmCt.startsWith('image/') ||
                    _esImagenValida(confirmResp.bodyBytes)) {
                  return confirmResp.bodyBytes;
                }
              }
            }
          }
        } catch (_) {
          // Esperar antes de reintentar (back-off lineal)
          if (intento < reintentos - 1) {
            await Future.delayed(Duration(seconds: intento + 1));
          }
        }
      }
    }
    return null; // todos los intentos fallaron
  }

  /// Genera los bytes del PDF sin mostrarlo ni compartirlo.
  /// Usado internamente por [generarReportePDF] y [compartirReportePDF],
  /// y también expuesto para que la UI pueda pre-construir el PDF con indicador de carga.
  static Future<({Uint8List bytes, String nombre, List<String> advertencias})> buildPdfBytes(
      Case? caso, Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final advertencias = <String>[];

    final String nombreCaso     = _obtenerValor(caso?.nombre,          data['nombre'])          ?? 'Sin Nombre';
    final String categoria      = _obtenerValor(caso?.tipoRiesgo,      data['tipoRiesgo'])      ?? 'N/A';
    final String tipoEspecifico = _obtenerValor(caso?.subgrupoRiesgo,  data['subgrupoRiesgo'])  ?? 'N/A';
    final String empresa        = _obtenerValor(caso?.empresaNombre,   data['empresaNombre'])   ?? 'N/A';
    final String centro         = _obtenerValor(caso?.centroNombre,    data['centroNombre'])    ?? 'Principal';

    final Map<String, dynamic> estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};

    final String nivelRiesgo  = _obtenerValor(caso?.nivelPeligro,   estadoAbierto['nivelPeligro'])   ?? data['nivelPeligro']   ?? 'N/A';
    final String ubicacion    = estadoAbierto['ubicacionTexto']         ?? 'N/A';
    final String descHallazgo = estadoAbierto['descripcionHallazgo']    ?? data['descripcionRiesgo'] ?? 'Sin descripción';
    final String control      = estadoAbierto['recomendacionesControl'] ?? 'N/A';
    final String nombreCliente = estadoAbierto['nombreCliente'] as String? ?? '';

    // Nombre del inspector: estadoAbierto → data raíz → perfil del usuario en Firestore
    String inspector = _obtenerValor(caso?.usuarioNombre, estadoAbierto['usuarioNombre'])
        ?? data['usuarioNombre'] as String?
        ?? '';

    DateTime fechaC;
    if (data['fechaCreacion'] is Timestamp) {
      fechaC = (data['fechaCreacion'] as Timestamp).toDate();
    } else {
      fechaC = caso?.fechaCreacion ?? DateTime.now();
    }
    final String fechaTexto = DateFormat('dd/MM/yyyy').format(fechaC);
    final String horaTexto  = DateFormat('HH:mm:ss').format(fechaC);

    // ── Lanzar todas las descargas en paralelo (mismo patrón que ReportService) ──
    final fotoFuture         = _cargarImagenHallazgo(estadoAbierto);
    final logoFuture         = _cargarLogoGrupo(data['grupoId'] as String?);
    final firmaInspFuture    = _cargarFirmaInspector(data['creadoPor'] as String?);
    final firmaClienteFuture = _cargarFirmaCliente(estadoAbierto);
    // Si no hay nombre del inspector, intentar obtenerlo del perfil del usuario
    final inspectorNameFuture = (inspector.isEmpty && data['creadoPor'] != null)
        ? _cargarNombreUsuario(data['creadoPor'] as String)
        : Future.value(null);

    final pw.MemoryImage? imageHallazgo      = await fotoFuture;
    final pw.MemoryImage? imagenLogo         = await logoFuture;
    final pw.MemoryImage? imagenFirmaInspector = await firmaInspFuture;
    final pw.MemoryImage? imagenFirmaCliente = await firmaClienteFuture;
    final String? inspectorFromProfile       = await inspectorNameFuture;
    if (inspector.isEmpty && inspectorFromProfile != null) {
      inspector = inspectorFromProfile;
    }
    if (inspector.isEmpty) inspector = 'N/A';

    if (imageHallazgo == null      && (estadoAbierto['fotoUrl']        as String?) != null) advertencias.add('No se pudo cargar la foto del hallazgo');
    if (imagenFirmaInspector == null && (data['creadoPor']             as String?) != null) advertencias.add('No se pudo cargar la firma del inspector');
    if (imagenFirmaCliente == null && (estadoAbierto['firmaClienteUrl'] as String?) != null) advertencias.add('No se pudo cargar la firma del cliente');

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
          _buildFirmas(inspector, nombreCliente, imagenFirmaInspector, imagenFirmaCliente),
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    return (bytes: bytes, nombre: "Reporte_$nombreCaso.pdf", advertencias: advertencias);
  }

  /// Abre el visor de impresión/PDF nativo del dispositivo.
  /// Retorna lista de advertencias (fotos/firmas que no se pudieron cargar).
  static Future<List<String>> generarReportePDF(Case? caso, Map<String, dynamic> data) async {
    final result = await buildPdfBytes(caso, data);
    await Printing.layoutPdf(
      onLayout: (_) async => result.bytes,
      name: result.nombre,
    );
    return result.advertencias;
  }

  /// Abre el menú nativo de compartir (WhatsApp, correo, Drive, etc.).
  /// Retorna lista de advertencias (fotos/firmas que no se pudieron cargar).
  static Future<List<String>> compartirReportePDF(Case? caso, Map<String, dynamic> data) async {
    final result = await buildPdfBytes(caso, data);
    await Printing.sharePdf(
      bytes: result.bytes,
      filename: result.nombre,
    );
    return result.advertencias;
  }

  // ── Helpers de carga de recursos (usados en paralelo desde buildPdfBytes) ──

  static Future<pw.MemoryImage?> _cargarImagenHallazgo(
      Map<String, dynamic> estadoAbierto) async {
    final bytes = await _descargarImagen(estadoAbierto['fotoUrl'] as String?);
    return bytes != null ? pw.MemoryImage(bytes) : null;
  }

  static Future<pw.MemoryImage?> _cargarLogoGrupo(String? grupoId) async {
    if (grupoId == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('grupos').doc(grupoId).get();
      final bytes = await _descargarImagen(doc.data()?['logoUrl'] as String?);
      return bytes != null ? pw.MemoryImage(bytes) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<pw.MemoryImage?> _cargarFirmaInspector(String? creadoPor) async {
    if (creadoPor == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(creadoPor).get();
      final bytes = await _descargarImagen(doc.data()?['firmaUrl'] as String?);
      return bytes != null ? pw.MemoryImage(bytes) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<pw.MemoryImage?> _cargarFirmaCliente(
      Map<String, dynamic> estadoAbierto) async {
    final bytes = await _descargarImagen(
        estadoAbierto['firmaClienteUrl'] as String?);
    return bytes != null ? pw.MemoryImage(bytes) : null;
  }

  /// Obtiene el displayName de un usuario desde Firestore.
  /// Usado como fallback cuando el inspector (ej. admin) no tiene
  /// usuarioNombre guardado en estadoAbierto.
  static Future<String?> _cargarNombreUsuario(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      return doc.data()?['displayName'] as String?;
    } catch (_) {
      return null;
    }
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