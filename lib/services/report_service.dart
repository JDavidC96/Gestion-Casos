// lib/services/report_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportService {
  
  // Generar reporte diario — mismo formato que PdfService, un bloque por caso apilado
  static Future<void> generarReporteCasosPDF({
    required List<QueryDocumentSnapshot> casos,
    required DateTime fecha,
    String? supervisor,
    bool incluirCerrados = true,
    required String empresaNombre,
    String? centroNombre,
    String? grupoId,
  }) async {

    final casosFiltrados = _filtrarCasosPorDia(
      casos: casos,
      fecha: fecha,
      supervisor: supervisor,
      incluirCerrados: incluirCerrados,
    );

    if (casosFiltrados.isEmpty) {
      throw Exception('No hay casos para el día seleccionado');
    }

    // Cargar imágenes de todos los casos antes de construir el PDF
    final List<pw.MemoryImage?> imagenes = await Future.wait(
      casosFiltrados.map((doc) async {
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
      }),
    );

    // ── Cargar logo del grupo ────────────────────────────────────────────
    pw.MemoryImage? imagenLogo;
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
        print('Error cargando logo: $e');
      }
    }

    // ── Cargar firma del inspector desde Firestore ───────────────────────
    pw.MemoryImage? firmaInspector;
    pw.MemoryImage? firmaCliente;
    if (casosFiltrados.isNotEmpty) {
      final primerDoc = casosFiltrados.first.data() as Map<String, dynamic>;
      final primerEstadoAb = primerDoc['estadoAbierto'] as Map<String, dynamic>? ?? {};
      // Firma inspector
      final String? creadoPor = primerDoc['creadoPor'] as String?;
      if (creadoPor != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users').doc(creadoPor).get();
          final String? firmaUrl = _convertirUrlDrive(
              userDoc.data()?['firmaUrl'] as String?);
          if (firmaUrl != null) {
            final firmaResp = await http.get(Uri.parse(firmaUrl))
                .timeout(const Duration(seconds: 15));
            if (firmaResp.statusCode == 200) {
              firmaInspector = pw.MemoryImage(firmaResp.bodyBytes);
            }
          }
        } catch (e) {
          print('Error cargando firma inspector: $e');
        }
      }
      // Firma cliente
      final String? firmaClienteUrl = _convertirUrlDrive(
          primerEstadoAb['firmaClienteUrl'] as String?);
      if (firmaClienteUrl != null) {
        try {
          final firmaClienteResp = await http.get(Uri.parse(firmaClienteUrl))
              .timeout(const Duration(seconds: 15));
          if (firmaClienteResp.statusCode == 200) {
            firmaCliente = pw.MemoryImage(firmaClienteResp.bodyBytes);
          }
        } catch (e) {
          print('Error cargando firma cliente: $e');
        }
      }
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];

          // Encabezado general del día (una sola vez arriba)
          widgets.add(_buildEncabezadoDiario(empresaNombre, centroNombre, fecha, supervisor, imagenLogo));
          widgets.add(pw.SizedBox(height: 10));

          // Un bloque por cada caso, en el mismo formato que PdfService
          for (int i = 0; i < casosFiltrados.length; i++) {
            final doc = casosFiltrados[i];
            final data = doc.data() as Map<String, dynamic>;
            final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};

            final nombreCaso    = _val(data['nombre']);
            final empresa       = _val(data['empresaNombre']) ?? empresaNombre;
            final centro        = _val(data['centroNombre']) ?? centroNombre ?? 'Principal';
            final inspector     = _val(estadoAbierto['usuarioNombre']) ?? _val(data['usuarioNombre']) ?? 'N/A';
            final ubicacion     = _val(estadoAbierto['ubicacionTexto']) ?? 'N/A';
            final desc          = _val(estadoAbierto['descripcionHallazgo']) ?? _val(data['descripcionRiesgo']) ?? 'Sin descripción';
            final nivel         = _val(estadoAbierto['nivelPeligro']) ?? _val(data['nivelPeligro']) ?? 'N/A';
            final control       = _val(estadoAbierto['recomendacionesControl']) ?? 'N/A';
            final categoria     = _val(data['tipoRiesgo']) ?? 'N/A';
            final tipoEsp       = _val(data['subgrupoRiesgo']) ?? 'N/A';
            final esCerrado     = data['cerrado'] == true;
            final estado        = esCerrado ? 'Completado' : 'Pendiente';

            DateTime fechaC;
            if (data['fechaCreacion'] is Timestamp) {
              fechaC = (data['fechaCreacion'] as Timestamp).toDate();
            } else {
              fechaC = fecha;
            }
            final fechaTexto = DateFormat('dd/MM/yyyy').format(fechaC);
            final horaTexto  = DateFormat('HH:mm:ss').format(fechaC);

            // Separador entre casos
            if (i > 0) {
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(pw.Divider(thickness: 0.5, color: PdfColors.grey400));
              widgets.add(pw.SizedBox(height: 4));
            }

            // Número de caso
            widgets.add(
              pw.Text(
                'Caso ${i + 1} de ${casosFiltrados.length}',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            );
            widgets.add(pw.SizedBox(height: 3));

            // Bloque idéntico al de PdfService
            widgets.add(_buildBloqueInspeccion(
              empresa: empresa,
              centro: centro,
              inspector: inspector,
              fechaTexto: fechaTexto,
              horaTexto: horaTexto,
              nombreCaso: nombreCaso ?? 'Sin nombre',
              categoria: categoria,
              tipoEspecifico: tipoEsp,
              ubicacion: ubicacion,
              desc: desc,
              nivel: nivel,
              control: control,
              estado: estado,
              imagen: imagenes[i],
            ));
          }

          // Resumen final
          widgets.add(pw.SizedBox(height: 12));
          widgets.add(_buildResumen(casosFiltrados));

          // Firmas al pie — nombre del inspector tomado del primer caso
          final primerData = casosFiltrados.first.data() as Map<String, dynamic>;
          final primerEstado = primerData['estadoAbierto'] as Map<String, dynamic>? ?? {};
          final nombreInspector = supervisor ??
              _val(primerEstado['usuarioNombre']) ??
              _val(primerData['usuarioNombre']) ??
              'Inspector';
          widgets.add(pw.SizedBox(height: 16));
          widgets.add(_buildFirmas(nombreInspector, centroNombre ?? empresaNombre, firmaInspector, firmaCliente));

          return widgets;
        },
      ),
    );

    final Uint8List bytesDiario = await pdf.save();
    final String nombreDiario = 'Reporte_Diario_${DateFormat('yyyyMMdd').format(fecha)}.pdf';
    await Printing.layoutPdf(
      onLayout: (_) async => bytesDiario,
      name: nombreDiario,
    );
  }

  /// Comparte el reporte diario via WhatsApp, correo, Drive, etc.
  static Future<void> compartirReporteCasosPDF({
    required List<QueryDocumentSnapshot> casos,
    required DateTime fecha,
    String? supervisor,
    bool incluirCerrados = true,
    required String empresaNombre,
    String? centroNombre,
    String? grupoId,
  }) async {
    final casosFiltrados = _filtrarCasosPorDia(
      casos: casos,
      fecha: fecha,
      supervisor: supervisor,
      incluirCerrados: incluirCerrados,
    );

    if (casosFiltrados.isEmpty) {
      throw Exception('No hay casos para el día seleccionado');
    }

    final List<pw.MemoryImage?> imagenes = await Future.wait(
      casosFiltrados.map((doc) async {
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
      }),
    );

    // ── Cargar logo del grupo ────────────────────────────────────────────
    pw.MemoryImage? imagenLogo2;
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
            imagenLogo2 = pw.MemoryImage(logoResp.bodyBytes);
          }
        }
      } catch (e) {
        print('Error cargando logo: $e');
      }
    }

    // ── Cargar firma del inspector desde Firestore ───────────────────────
    pw.MemoryImage? firmaInspector2;
    pw.MemoryImage? firmaCliente2;
    if (casosFiltrados.isNotEmpty) {
      final primerDoc2 = casosFiltrados.first.data() as Map<String, dynamic>;
      final primerEstadoAb2 = primerDoc2['estadoAbierto'] as Map<String, dynamic>? ?? {};
      // Firma inspector
      final String? creadoPor2 = primerDoc2['creadoPor'] as String?;
      if (creadoPor2 != null) {
        try {
          final userDoc2 = await FirebaseFirestore.instance
              .collection('users').doc(creadoPor2).get();
          final String? firmaUrl2 = _convertirUrlDrive(
              userDoc2.data()?['firmaUrl'] as String?);
          if (firmaUrl2 != null) {
            final firmaResp2 = await http.get(Uri.parse(firmaUrl2))
                .timeout(const Duration(seconds: 15));
            if (firmaResp2.statusCode == 200) {
              firmaInspector2 = pw.MemoryImage(firmaResp2.bodyBytes);
            }
          }
        } catch (e) {
          print('Error cargando firma inspector: $e');
        }
      }
      // Firma cliente
      final String? firmaClienteUrl2 = _convertirUrlDrive(
          primerEstadoAb2['firmaClienteUrl'] as String?);
      if (firmaClienteUrl2 != null) {
        try {
          final firmaClienteResp2 = await http.get(Uri.parse(firmaClienteUrl2))
              .timeout(const Duration(seconds: 15));
          if (firmaClienteResp2.statusCode == 200) {
            firmaCliente2 = pw.MemoryImage(firmaClienteResp2.bodyBytes);
          }
        } catch (e) {
          print('Error cargando firma cliente: $e');
        }
      }
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];
          widgets.add(_buildEncabezadoDiario(empresaNombre, centroNombre, fecha, supervisor, imagenLogo2));
          widgets.add(pw.SizedBox(height: 10));
          for (int i = 0; i < casosFiltrados.length; i++) {
            final doc = casosFiltrados[i];
            final data = doc.data() as Map<String, dynamic>;
            final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};
            final nombreCaso    = _val(data['nombre']);
            final empresa       = _val(data['empresaNombre']) ?? empresaNombre;
            final centro        = _val(data['centroNombre']) ?? centroNombre ?? 'Principal';
            final inspector     = _val(estadoAbierto['usuarioNombre']) ?? _val(data['usuarioNombre']) ?? 'N/A';
            final ubicacion     = _val(estadoAbierto['ubicacionTexto']) ?? 'N/A';
            final desc          = _val(estadoAbierto['descripcionHallazgo']) ?? _val(data['descripcionRiesgo']) ?? 'Sin descripción';
            final nivel         = _val(estadoAbierto['nivelPeligro']) ?? _val(data['nivelPeligro']) ?? 'N/A';
            final control       = _val(estadoAbierto['recomendacionesControl']) ?? 'N/A';
            final categoria     = _val(data['tipoRiesgo']) ?? 'N/A';
            final tipoEsp       = _val(data['subgrupoRiesgo']) ?? 'N/A';
            final esCerrado     = data['cerrado'] == true;
            final estado        = esCerrado ? 'Completado' : 'Pendiente';
            DateTime fechaC;
            if (data['fechaCreacion'] is Timestamp) {
              fechaC = (data['fechaCreacion'] as Timestamp).toDate();
            } else {
              fechaC = fecha;
            }
            final fechaTexto = DateFormat('dd/MM/yyyy').format(fechaC);
            final horaTexto  = DateFormat('HH:mm:ss').format(fechaC);
            if (i > 0) {
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(pw.Divider(thickness: 0.5, color: PdfColors.grey400));
              widgets.add(pw.SizedBox(height: 4));
            }
            widgets.add(pw.Text('Caso ${i + 1} de ${casosFiltrados.length}',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)));
            widgets.add(pw.SizedBox(height: 3));
            widgets.add(_buildBloqueInspeccion(
              empresa: empresa, centro: centro, inspector: inspector,
              fechaTexto: fechaTexto, horaTexto: horaTexto,
              nombreCaso: nombreCaso ?? 'Sin nombre', categoria: categoria,
              tipoEspecifico: tipoEsp, ubicacion: ubicacion, desc: desc,
              nivel: nivel, control: control, estado: estado, imagen: imagenes[i],
            ));
          }
          widgets.add(pw.SizedBox(height: 12));
          widgets.add(_buildResumen(casosFiltrados));
          // Firmas al pie — nombre del inspector tomado del primer caso
          final primerData2 = casosFiltrados.first.data() as Map<String, dynamic>;
          final primerEstado2 = primerData2['estadoAbierto'] as Map<String, dynamic>? ?? {};
          final nombreInspector2 = supervisor ??
              _val(primerEstado2['usuarioNombre']) ??
              _val(primerData2['usuarioNombre']) ??
              'Inspector';
          widgets.add(pw.SizedBox(height: 16));
          widgets.add(_buildFirmas(nombreInspector2, centroNombre ?? empresaNombre, firmaInspector2, firmaCliente2));
          return widgets;
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Reporte_Diario_${DateFormat('yyyyMMdd').format(fecha)}.pdf',
    );
  }

  // ─── HELPERS REPORTE DIARIO ──────────────────────────────────────────────────

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
              child: pw.Text('v.01',
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center),
            ),
          ),
          // Logo esquina superior derecha
          pw.Container(
            height: 36,
            padding: const pw.EdgeInsets.all(3),
            child: logo != null
                ? pw.Image(logo, fit: pw.BoxFit.contain)
                : pw.Center(
                    child: pw.Text('LOGO',
                        style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey))),
          ),
        ]),
      ],
    );
  }

  // Bloque idéntico al diseño de PdfService: info general + tabla de detalle
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
        // Sección 1 — Información General
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
        // Sección 2 — Detalle del Hallazgo
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
                  .map(_celdaHeaderLocal)
                  .toList(),
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
                    : pw.Center(
                        child: pw.Text('Sin foto',
                            style: const pw.TextStyle(fontSize: 6))),
              ),
            ]),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tituloSeccion(String t) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text(t,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
      );

  static pw.TableRow _filaInfo(String l1, String v1, String l2, String v2) =>
      pw.TableRow(children: [
        pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Text('$l1: $v1', style: const pw.TextStyle(fontSize: 7))),
        pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Text('$l2: $v2', style: const pw.TextStyle(fontSize: 7))),
      ]);

  static pw.Widget _celdaHeaderLocal(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(t,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
      );

  static pw.Widget _celdaDataLocal(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(t, style: const pw.TextStyle(fontSize: 6.5)),
      );

  // Generar reporte mensual por centros de trabajo — formato exacto de la imagen
  static Future<void> generarReporteMensualCentrosPDF({
    required Map<String, List<QueryDocumentSnapshot>> casosPorCentro,
    required int mes,
    required int anio,
    String? supervisor,
    bool incluirCerrados = true,
    required String empresaNombre,
    String? grupoId,
  }) async {
    
    // ── Cargar logo del grupo ────────────────────────────────────────────
    pw.MemoryImage? imagenLogoMensual;
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
            imagenLogoMensual = pw.MemoryImage(logoResp.bodyBytes);
          }
        }
      } catch (e) {
        print('Error cargando logo: $e');
      }
    }

    final pdf = pw.Document();
    
    // Formato oficio landscape: 216mm x 330mm → landscape = 330mm x 216mm
    const pageFormat = PdfPageFormat(
      330 * PdfPageFormat.mm,
      216 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        build: (pw.Context context) {
          return [
            _buildHeaderMensualFormatoImagen(empresaNombre, mes, anio, imagenLogoMensual),
            pw.SizedBox(height: 6),
            _buildTablaCentrosFormatoImagen(casosPorCentro, mes, anio),
            _buildResumenMensual(casosPorCentro),
          ];
        },
      ),
    );

    final Uint8List bytesMensual = await pdf.save();
    final String nombreMensual = 'Reporte_Mensual_Centros_${_getNombreMes(mes)}_$anio.pdf';
    await Printing.layoutPdf(
      onLayout: (_) async => bytesMensual,
      name: nombreMensual,
    );
  }

  /// Comparte el reporte mensual via WhatsApp, correo, Drive, etc.
  static Future<void> compartirReporteMensualCentrosPDF({
    required Map<String, List<QueryDocumentSnapshot>> casosPorCentro,
    required int mes,
    required int anio,
    String? supervisor,
    bool incluirCerrados = true,
    required String empresaNombre,
    String? grupoId,
  }) async {
    // ── Cargar logo del grupo ────────────────────────────────────────────
    pw.MemoryImage? imagenLogoMensual2;
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
            imagenLogoMensual2 = pw.MemoryImage(logoResp.bodyBytes);
          }
        }
      } catch (e) {
        print('Error cargando logo: $e');
      }
    }
    final pdf = pw.Document();
    const pageFormat = PdfPageFormat(
      330 * PdfPageFormat.mm,
      216 * PdfPageFormat.mm,
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        build: (pw.Context context) => [
          _buildHeaderMensualFormatoImagen(empresaNombre, mes, anio, imagenLogoMensual2),
          pw.SizedBox(height: 6),
          _buildTablaCentrosFormatoImagen(casosPorCentro, mes, anio),
          _buildResumenMensual(casosPorCentro),
        ],
      ),
    );
    final Uint8List bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Reporte_Mensual_Centros_${_getNombreMes(mes)}_$anio.pdf',
    );
  }

  // ─── FILTROS ────────────────────────────────────────────────────────────────

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
      
      final dentroDeFecha = fechaCreacion.isAfter(fechaInicio) && 
                           fechaCreacion.isBefore(fechaFin);
      if (!dentroDeFecha) return false;

      if (supervisor != null && supervisor.isNotEmpty) {
        final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>?;
        final usuarioNombre = estadoAbierto?['usuarioNombre'] ?? data['usuarioNombre'];
        if (usuarioNombre != supervisor) return false;
      }

      if (!incluirCerrados && data['cerrado'] == true) return false;

      return true;
    }).toList();
  }

  // ─── HEADER MENSUAL — formato imagen ────────────────────────────────────────

  static pw.Widget _buildHeaderMensualFormatoImagen(String empresa, int mes, int anio,
      [pw.MemoryImage? logo]) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(100),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(60),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Container(
              height: 45,
              padding: const pw.EdgeInsets.all(4),
              child: pw.Center(
                child: pw.Text(
                  empresa,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
            pw.Container(
              height: 45,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'SISTEMA DE GESTIÓN EN SEGURIDAD Y SALUD EN EL TRABAJO',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'CONTROL DE INSPECCIONES',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Período: ${_getNombreMes(mes)} $anio',
                    style: const pw.TextStyle(fontSize: 7),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            // Logo esquina superior derecha
            pw.Container(
              height: 45,
              padding: const pw.EdgeInsets.all(4),
              child: logo != null
                  ? pw.Image(logo, fit: pw.BoxFit.contain)
                  : pw.Center(
                      child: pw.Text('VERSION 2',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                          textAlign: pw.TextAlign.center)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── TABLA MENSUAL — formato exacto de la imagen ────────────────────────────

  static pw.Widget _buildTablaCentrosFormatoImagen(
    Map<String, List<QueryDocumentSnapshot>> casosPorCentro,
    int mes,
    int anio,
  ) {
    const double fs = 6.0; // fuente uniforme pequeña para caber en oficio landscape

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(46),  // FECHA
        1: const pw.FlexColumnWidth(2.2),  // INSPECTOR
        2: const pw.FixedColumnWidth(44),  // CENTRO DE TRABAJO
        3: const pw.FlexColumnWidth(1.8),  // UBICACIÓN ESPECÍFICA
        4: const pw.FlexColumnWidth(3.2),  // DESCRIPCION HALLAZGO
        5: const pw.FixedColumnWidth(34),  // NIVEL DE PELIGRO
        6: const pw.FlexColumnWidth(3.0),  // CONTROL
        7: const pw.FixedColumnWidth(38),  // ESTADO DEL CONTROL
      },
      children: [
        // Encabezados
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
        // Filas de datos
        ...casosPorCentro.entries.expand((entry) {
          final centroNombre = entry.key;
          return entry.value.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>? ?? {};
            final fecha = (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now();
            final esCerrado = data['cerrado'] == true;

            final inspector = estadoAbierto['usuarioNombre'] ?? data['usuarioNombre'] ?? 'N/A';
            final ubicacion = estadoAbierto['ubicacionTexto'] ?? 'N/A';
            final descHallazgo = estadoAbierto['descripcionHallazgo'] ?? data['descripcionRiesgo'] ?? 'Sin hallazgos';
            final nivelPeligro = estadoAbierto['nivelPeligro'] ?? data['nivelPeligro'] ?? 'N/A';
            final control = estadoAbierto['recomendacionesControl'] ?? 'No Aplica';
            final estado = esCerrado ? 'Completado' : 'Pendiente';

            return pw.TableRow(
              children: [
                _celdaData(DateFormat('dd/MM/yy\nHH:mm').format(fecha), fontSize: fs),
                _celdaData(inspector, fontSize: fs, maxLength: 28),
                _celdaData(centroNombre, fontSize: fs, maxLength: 20),
                _celdaData(ubicacion, fontSize: fs, maxLength: 25),
                _celdaData(descHallazgo, fontSize: fs, maxLength: 80),
                _celdaData(nivelPeligro, fontSize: fs, maxLength: 12),
                _celdaData(control, fontSize: fs, maxLength: 70),
                _celdaData(estado, fontSize: fs),
              ],
            );
          });
        }),
      ],
    );
  }

  // ─── RESÚMENES ───────────────────────────────────────────────────────────────

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
            pw.Text('• ${e.key}: ${e.value.length} casos')
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

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

  // ── Sección de firmas al pie del reporte ─────────────────────────────────
  static pw.Widget _buildFirmas(String inspectorNombre, String centroNombre,
      [pw.MemoryImage? firmaInspector, pw.MemoryImage? firmaCliente]) =>
      pw.Table(
    border: pw.TableBorder.all(width: 0.5),
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
              'FIRMA DEL INSPECTOR',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'FIRMA DEL RESPONSABLE / CLIENTE',
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