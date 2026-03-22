// lib/services/report_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportService {

  // ═══════════════════════════════════════════════════════════════════
  //  API PÚBLICA — Reporte Diario
  // ═══════════════════════════════════════════════════════════════════

  static Future<void> generarReporteCasosPDF({
    required List<QueryDocumentSnapshot> casos,
    required DateTime fecha,
    String? supervisor,
    bool incluirCerrados = true,
    required String empresaNombre,
    String? centroNombre,
    String? grupoId,
  }) async {
    final result = await _buildReporteDiarioBytes(
      casos: casos, fecha: fecha, supervisor: supervisor,
      incluirCerrados: incluirCerrados, empresaNombre: empresaNombre,
      centroNombre: centroNombre, grupoId: grupoId,
    );
    await Printing.layoutPdf(onLayout: (_) async => result.bytes, name: result.nombre);
  }

  static Future<void> compartirReporteCasosPDF({
    required List<QueryDocumentSnapshot> casos,
    required DateTime fecha,
    String? supervisor,
    bool incluirCerrados = true,
    required String empresaNombre,
    String? centroNombre,
    String? grupoId,
  }) async {
    final result = await _buildReporteDiarioBytes(
      casos: casos, fecha: fecha, supervisor: supervisor,
      incluirCerrados: incluirCerrados, empresaNombre: empresaNombre,
      centroNombre: centroNombre, grupoId: grupoId,
    );
    await Printing.sharePdf(bytes: result.bytes, filename: result.nombre);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  API PÚBLICA — Reporte Mensual por Centros
  // ═══════════════════════════════════════════════════════════════════

  static Future<void> generarReporteMensualCentrosPDF({
    required Map<String, List<QueryDocumentSnapshot>> casosPorCentro,
    required int mes,
    required int anio,
    String? supervisor,
    bool incluirCerrados = true,
    required String empresaNombre,
    String? grupoId,
  }) async {
    final result = await _buildReporteMensualBytes(
      casosPorCentro: casosPorCentro, mes: mes, anio: anio,
      supervisor: supervisor, incluirCerrados: incluirCerrados,
      empresaNombre: empresaNombre, grupoId: grupoId,
    );
    await Printing.layoutPdf(onLayout: (_) async => result.bytes, name: result.nombre);
  }

  static Future<void> compartirReporteMensualCentrosPDF({
    required Map<String, List<QueryDocumentSnapshot>> casosPorCentro,
    required int mes,
    required int anio,
    String? supervisor,
    bool incluirCerrados = true,
    required String empresaNombre,
    String? grupoId,
  }) async {
    final result = await _buildReporteMensualBytes(
      casosPorCentro: casosPorCentro, mes: mes, anio: anio,
      supervisor: supervisor, incluirCerrados: incluirCerrados,
      empresaNombre: empresaNombre, grupoId: grupoId,
    );
    await Printing.sharePdf(bytes: result.bytes, filename: result.nombre);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  GENERADORES DE BYTES (privados, sin duplicación)
  // ═══════════════════════════════════════════════════════════════════

  /// Genera los bytes del PDF diario.
  static Future<({Uint8List bytes, String nombre})> _buildReporteDiarioBytes({
    required List<QueryDocumentSnapshot> casos,
    required DateTime fecha,
    String? supervisor,
    required bool incluirCerrados,
    required String empresaNombre,
    String? centroNombre,
    String? grupoId,
  }) async {
    final casosFiltrados = _filtrarCasosPorDia(
      casos: casos, fecha: fecha,
      supervisor: supervisor, incluirCerrados: incluirCerrados,
    );

    if (casosFiltrados.isEmpty) {
      throw Exception('No hay casos para el día seleccionado');
    }

    // Cargar recursos en paralelo
    final imagenesFuture = Future.wait(
      casosFiltrados.map((doc) => _cargarImagenCaso(doc)),
    );
    final logoFuture = _cargarLogoGrupo(grupoId);
    final firmasFuture = _cargarFirmasPrimerCaso(casosFiltrados.first);

    final imagenes = await imagenesFuture;
    final imagenLogo = await logoFuture;
    final firmas = await firmasFuture;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];

          widgets.add(_buildEncabezadoDiario(empresaNombre, centroNombre, fecha, supervisor, imagenLogo));
          widgets.add(pw.SizedBox(height: 10));

          for (int i = 0; i < casosFiltrados.length; i++) {
            if (i > 0) {
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(pw.Divider(thickness: 0.5, color: PdfColors.grey400));
              widgets.add(pw.SizedBox(height: 4));
            }

            widgets.add(pw.Text(
              'Caso ${i + 1} de ${casosFiltrados.length}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ));
            widgets.add(pw.SizedBox(height: 3));
            widgets.add(_buildBloqueDesdeDoc(
              casosFiltrados[i], empresaNombre, centroNombre, fecha, imagenes[i],
            ));
          }

          widgets.add(pw.SizedBox(height: 12));
          widgets.add(_buildResumen(casosFiltrados));

          final primerData = casosFiltrados.first.data() as Map<String, dynamic>;
          final primerEstado = primerData['estadoAbierto'] as Map<String, dynamic>? ?? {};
          final nombreInspector = supervisor ??
              _val(primerEstado['usuarioNombre']) ??
              _val(primerData['usuarioNombre']) ??
              'Inspector';
          widgets.add(pw.SizedBox(height: 16));
          widgets.add(_buildFirmas(nombreInspector, centroNombre ?? empresaNombre,
              firmas.inspector, firmas.cliente));

          return widgets;
        },
      ),
    );

    final bytes = await pdf.save();
    final nombre = 'Reporte_Diario_${DateFormat('yyyyMMdd').format(fecha)}.pdf';
    return (bytes: bytes, nombre: nombre);
  }

  /// Genera los bytes del PDF mensual por centros.
  static Future<({Uint8List bytes, String nombre})> _buildReporteMensualBytes({
    required Map<String, List<QueryDocumentSnapshot>> casosPorCentro,
    required int mes,
    required int anio,
    String? supervisor,
    required bool incluirCerrados,
    required String empresaNombre,
    String? grupoId,
  }) async {
    final imagenLogo = await _cargarLogoGrupo(grupoId);

    final pdf = pw.Document();

    // Formato oficio landscape: 330mm x 216mm
    const pageFormat = PdfPageFormat(
      330 * PdfPageFormat.mm,
      216 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        build: (pw.Context context) => [
          _buildHeaderMensual(empresaNombre, mes, anio, imagenLogo),
          pw.SizedBox(height: 6),
          _buildTablaCentros(casosPorCentro, mes, anio),
          _buildResumenMensual(casosPorCentro),
        ],
      ),
    );

    final bytes = await pdf.save();
    final nombre = 'Reporte_Mensual_Centros_${_getNombreMes(mes)}_$anio.pdf';
    return (bytes: bytes, nombre: nombre);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CARGA DE RECURSOS (logo, imágenes, firmas)
  // ═══════════════════════════════════════════════════════════════════

  static Future<pw.MemoryImage?> _cargarImagenCaso(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};
    final fotoUrl = _convertirUrlDrive(estadoAbierto['fotoUrl'] as String?);
    if (fotoUrl == null) return null;
    try {
      final response = await http.get(Uri.parse(fotoUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return pw.MemoryImage(response.bodyBytes);
    } catch (_) {}
    return null;
  }

  static Future<pw.MemoryImage?> _cargarLogoGrupo(String? grupoId) async {
    if (grupoId == null) return null;
    try {
      final grupoDoc = await FirebaseFirestore.instance
          .collection('grupos').doc(grupoId).get();
      final logoUrl = _convertirUrlDrive(grupoDoc.data()?['logoUrl'] as String?);
      if (logoUrl == null) return null;
      final resp = await http.get(Uri.parse(logoUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return pw.MemoryImage(resp.bodyBytes);
    } catch (_) {}
    return null;
  }

  static Future<({pw.MemoryImage? inspector, pw.MemoryImage? cliente})>
      _cargarFirmasPrimerCaso(QueryDocumentSnapshot primerDoc) async {
    final data = primerDoc.data() as Map<String, dynamic>;
    final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};

    pw.MemoryImage? firmaInspector;
    pw.MemoryImage? firmaCliente;

    // Firma inspector
    final creadoPor = data['creadoPor'] as String?;
    if (creadoPor != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(creadoPor).get();
        final firmaUrl = _convertirUrlDrive(userDoc.data()?['firmaUrl'] as String?);
        if (firmaUrl != null) {
          final resp = await http.get(Uri.parse(firmaUrl))
              .timeout(const Duration(seconds: 15));
          if (resp.statusCode == 200) firmaInspector = pw.MemoryImage(resp.bodyBytes);
        }
      } catch (_) {}
    }

    // Firma cliente
    final firmaClienteUrl = _convertirUrlDrive(estadoAbierto['firmaClienteUrl'] as String?);
    if (firmaClienteUrl != null) {
      try {
        final resp = await http.get(Uri.parse(firmaClienteUrl))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) firmaCliente = pw.MemoryImage(resp.bodyBytes);
      } catch (_) {}
    }

    return (inspector: firmaInspector, cliente: firmaCliente);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CONSTRUCCIÓN DE BLOQUES PDF
  // ═══════════════════════════════════════════════════════════════════

  /// Extrae datos de un doc y construye el bloque de inspección.
  static pw.Widget _buildBloqueDesdeDoc(
    QueryDocumentSnapshot doc,
    String empresaNombreFallback,
    String? centroNombreFallback,
    DateTime fechaFallback,
    pw.MemoryImage? imagen,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};

    DateTime fechaC;
    if (data['fechaCreacion'] is Timestamp) {
      fechaC = (data['fechaCreacion'] as Timestamp).toDate();
    } else {
      fechaC = fechaFallback;
    }

    return _buildBloqueInspeccion(
      empresa:        _val(data['empresaNombre']) ?? empresaNombreFallback,
      centro:         _val(data['centroNombre']) ?? centroNombreFallback ?? 'Principal',
      inspector:      _val(estadoAbierto['usuarioNombre']) ?? _val(data['usuarioNombre']) ?? 'N/A',
      fechaTexto:     DateFormat('dd/MM/yyyy').format(fechaC),
      horaTexto:      DateFormat('HH:mm:ss').format(fechaC),
      nombreCaso:     _val(data['nombre']) ?? 'Sin nombre',
      categoria:      _val(data['tipoRiesgo']) ?? 'N/A',
      tipoEspecifico: _val(data['subgrupoRiesgo']) ?? 'N/A',
      ubicacion:      _val(estadoAbierto['ubicacionTexto']) ?? 'N/A',
      desc:           _val(estadoAbierto['descripcionHallazgo']) ?? _val(data['descripcionRiesgo']) ?? 'Sin descripción',
      nivel:          _val(estadoAbierto['nivelPeligro']) ?? _val(data['nivelPeligro']) ?? 'N/A',
      control:        _val(estadoAbierto['recomendacionesControl']) ?? 'N/A',
      estado:         data['cerrado'] == true ? 'Completado' : 'Pendiente',
      imagen:         imagen,
    );
  }

  static pw.Widget _buildBloqueInspeccion({
    required String empresa,
    required String centro,
    required String inspector,
    required String fechaTexto,
    required String horaTexto,
    required String nombreCaso,
    required String categoria,
    required String tipoEspecifico,
    required String ubicacion,
    required String desc,
    required String nivel,
    required String control,
    required String estado,
    pw.MemoryImage? imagen,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _tituloSeccion('1. Información General'),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          children: [
            _filaInfo('Empresa', empresa, 'Fecha', fechaTexto),
            _filaInfo('Centro', centro, 'Hora', horaTexto),
            _filaInfo('Inspector', inspector, 'Estado', estado),
          ],
        ),
        pw.SizedBox(height: 4),
        _tituloSeccion('2. Detalle del Hallazgo'),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            4: const pw.FlexColumnWidth(2),
            7: const pw.FixedColumnWidth(90),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['Caso', 'Categoría', 'Tipo', 'Ubicación', 'Descripción', 'Nivel Peligro', 'Control', 'Evidencia']
                  .map(_celdaHeaderLocal).toList(),
            ),
            pw.TableRow(children: [
              _celdaDataLocal(nombreCaso),
              _celdaDataLocal(categoria),
              _celdaDataLocal(tipoEspecifico),
              _celdaDataLocal(ubicacion),
              _celdaDataLocal(desc),
              _celdaDataLocal(nivel),
              _celdaDataLocal(control),
              pw.Container(
                height: 70,
                child: imagen != null
                    ? pw.Image(imagen, fit: pw.BoxFit.contain)
                    : pw.Center(child: pw.Text('Sin foto', style: const pw.TextStyle(fontSize: 6))),
              ),
            ]),
          ],
        ),
      ],
    );
  }

  // ─── Encabezado Diario ───────────────────────────────────────────────────

  static pw.Widget _buildEncabezadoDiario(
      String empresa, String? centro, DateTime fecha, String? supervisor,
      [pw.MemoryImage? logo]) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FixedColumnWidth(60),
      },
      children: [
        pw.TableRow(children: [
          pw.Container(
            height: 36,
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('REGISTRO DE INSPECCIÓN',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    textAlign: pw.TextAlign.center),
                pw.Text(
                  '${centro != null ? "Centro: $centro   " : ""}Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}${supervisor != null && supervisor.isNotEmpty ? "   Inspector: $supervisor" : ""}',
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
          pw.Container(
            height: 36,
            padding: const pw.EdgeInsets.all(4),
            child: pw.Center(
              child: pw.Text('v.01', style: const pw.TextStyle(fontSize: 7)),
            ),
          ),
          pw.Container(
            height: 36,
            padding: const pw.EdgeInsets.all(3),
            child: logo != null
                ? pw.Image(logo, fit: pw.BoxFit.contain)
                : pw.Center(child: pw.Text('LOGO',
                    style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey))),
          ),
        ]),
      ],
    );
  }

  // ─── Header Mensual ──────────────────────────────────────────────────────

  static pw.Widget _buildHeaderMensual(String empresa, int mes, int anio,
      [pw.MemoryImage? logo]) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(100),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(60),
      },
      children: [
        pw.TableRow(children: [
          pw.Container(
            height: 45,
            padding: const pw.EdgeInsets.all(4),
            child: pw.Center(
              child: pw.Text(empresa,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                  textAlign: pw.TextAlign.center),
            ),
          ),
          pw.Container(
            height: 45,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('SISTEMA DE GESTIÓN EN SEGURIDAD Y SALUD EN EL TRABAJO',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                    textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 4),
                pw.Text('CONTROL DE INSPECCIONES',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 3),
                pw.Text('Período: ${_getNombreMes(mes)} $anio',
                    style: const pw.TextStyle(fontSize: 7),
                    textAlign: pw.TextAlign.center),
              ],
            ),
          ),
          pw.Container(
            height: 45,
            padding: const pw.EdgeInsets.all(4),
            child: logo != null
                ? pw.Image(logo, fit: pw.BoxFit.contain)
                : pw.Center(child: pw.Text('VERSION 2',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
          ),
        ]),
      ],
    );
  }

  // ─── Tabla Mensual por Centros ───────────────────────────────────────────

  static pw.Widget _buildTablaCentros(
    Map<String, List<QueryDocumentSnapshot>> casosPorCentro, int mes, int anio,
  ) {
    const double fs = 6.0;

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(46),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FixedColumnWidth(44),
        3: const pw.FlexColumnWidth(1.8),
        4: const pw.FlexColumnWidth(3.2),
        5: const pw.FixedColumnWidth(34),
        6: const pw.FlexColumnWidth(3.0),
        7: const pw.FixedColumnWidth(38),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _celdaHeader('FECHA', fontSize: fs),
            _celdaHeader('INSPECTOR', fontSize: fs),
            _celdaHeader('CENTRO DE\nTRABAJO', fontSize: fs),
            _celdaHeader('UBICACIÓN\nESPECÍFICA', fontSize: fs),
            _celdaHeader('DESCRIPCIÓN\nHALLAZGO', fontSize: fs),
            _celdaHeader('NIVEL\nPELIGRO', fontSize: fs),
            _celdaHeader('CONTROL', fontSize: fs),
            _celdaHeader('ESTADO DEL\nCONTROL', fontSize: fs),
          ],
        ),
        ...casosPorCentro.entries.expand((entry) {
          final centroNombre = entry.key;
          return entry.value.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};
            final fecha = (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now();
            final esCerrado = data['cerrado'] == true;

            return pw.TableRow(children: [
              _celdaData(DateFormat('dd/MM/yy\nHH:mm').format(fecha), fontSize: fs),
              _celdaData(estadoAbierto['usuarioNombre'] ?? data['usuarioNombre'] ?? 'N/A', fontSize: fs, maxLength: 28),
              _celdaData(centroNombre, fontSize: fs, maxLength: 20),
              _celdaData(estadoAbierto['ubicacionTexto'] ?? 'N/A', fontSize: fs, maxLength: 25),
              _celdaData(estadoAbierto['descripcionHallazgo'] ?? data['descripcionRiesgo'] ?? 'Sin hallazgos', fontSize: fs, maxLength: 80),
              _celdaData(estadoAbierto['nivelPeligro'] ?? data['nivelPeligro'] ?? 'N/A', fontSize: fs, maxLength: 12),
              _celdaData(estadoAbierto['recomendacionesControl'] ?? 'No Aplica', fontSize: fs, maxLength: 70),
              _celdaData(esCerrado ? 'Completado' : 'Pendiente', fontSize: fs),
            ]);
          });
        }),
      ],
    );
  }

  // ─── Resúmenes ───────────────────────────────────────────────────────────

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
          pw.Text('Pendientes: $abiertos'),
          pw.Text('Completados: $cerrados'),
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
            pw.Text('${e.key}: ${e.value.length} casos')
          ),
        ],
      ),
    );
  }

  // ─── Firmas ──────────────────────────────────────────────────────────────

  static pw.Widget _buildFirmas(String inspectorNombre, String centroNombre,
      [pw.MemoryImage? firmaInspector, pw.MemoryImage? firmaCliente]) =>
      pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(1),
      1: const pw.FlexColumnWidth(1),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('FIRMA DEL INSPECTOR',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                textAlign: pw.TextAlign.center),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('FIRMA DEL RESPONSABLE / CLIENTE',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                textAlign: pw.TextAlign.center),
          ),
        ],
      ),
      pw.TableRow(children: [
        pw.Container(
          height: 50, padding: const pw.EdgeInsets.all(4),
          child: pw.Center(child: firmaInspector != null
              ? pw.Image(firmaInspector, fit: pw.BoxFit.contain) : pw.SizedBox()),
        ),
        pw.Container(
          height: 50, padding: const pw.EdgeInsets.all(4),
          child: pw.Center(child: firmaCliente != null
              ? pw.Image(firmaCliente, fit: pw.BoxFit.contain) : pw.SizedBox()),
        ),
      ]),
      pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(inspectorNombre, style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(centroNombre, style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center),
        ),
      ]),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  //  FILTROS Y HELPERS
  // ═══════════════════════════════════════════════════════════════════

  static String? _val(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'N/A' || s == 'null') return null;
    return s;
  }

  static String? _convertirUrlDrive(String? url) {
    if (url == null) return null;
    if (url.contains('drive.google.com')) {
      final id = RegExp(r'\/d\/([a-zA-Z0-9-_]+)').firstMatch(url)?.group(1);
      if (id != null) return 'https://drive.google.com/uc?export=download&id=$id';
    }
    return url;
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
      final fechaCreacion = (data['fechaCreacion'] as Timestamp?)?.toDate();
      if (fechaCreacion == null) return false;
      if (!fechaCreacion.isAfter(fechaInicio) || !fechaCreacion.isBefore(fechaFin)) return false;
      if (supervisor != null && supervisor.isNotEmpty) {
        final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>?;
        final usuarioNombre = estadoAbierto?['usuarioNombre'] ?? data['usuarioNombre'];
        if (usuarioNombre != supervisor) return false;
      }
      if (!incluirCerrados && data['cerrado'] == true) return false;
      return true;
    }).toList();
  }

  static pw.Widget _tituloSeccion(String t) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
  );

  static pw.TableRow _filaInfo(String l1, String v1, String l2, String v2) =>
      pw.TableRow(children: [
        pw.Padding(padding: const pw.EdgeInsets.all(3),
            child: pw.Text('$l1: $v1', style: const pw.TextStyle(fontSize: 7))),
        pw.Padding(padding: const pw.EdgeInsets.all(3),
            child: pw.Text('$l2: $v2', style: const pw.TextStyle(fontSize: 7))),
      ]);

  static pw.Widget _celdaHeaderLocal(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(3),
    child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
  );

  static pw.Widget _celdaDataLocal(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(3),
    child: pw.Text(t, style: const pw.TextStyle(fontSize: 6.5)),
  );

  static pw.Widget _celdaHeader(String texto, {double fontSize = 9}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(texto,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize),
          textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _celdaData(String texto, {double fontSize = 8, int? maxLength}) {
    String displayText = texto;
    if (maxLength != null && displayText.length > maxLength) {
      displayText = '${displayText.substring(0, maxLength)}...';
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(displayText, style: pw.TextStyle(fontSize: fontSize)),
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