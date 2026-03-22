// lib/services/camera_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'geolocation_service.dart';

/// Resultado de la captura de foto (sin subir a Drive).
class CapturaFotoResult {
  final String fotoPath;
  final Position? ubicacion;
  final XFile xFile;
  final DateTime fecha;

  CapturaFotoResult({
    required this.fotoPath,
    required this.xFile,
    this.ubicacion,
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();
}

/// Resultado de subida a Drive.
class SubidaDriveResult {
  final bool exitoso;
  final String? url;
  final String mensaje;

  const SubidaDriveResult.ok(this.url)
      : exitoso = true,
        mensaje = 'Archivo subido exitosamente';

  const SubidaDriveResult.error(this.mensaje)
      : exitoso = false,
        url = null;
}

class CameraService {
  static final ImagePicker _picker = ImagePicker();

  // URL de tu Google Apps Script
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbyEnp9do9mJT_90v7__UopJB0ne0ZpCHwXQyvG9DUN5I5j3LWN9heOt_2ief8o9iodu/exec';

  /// PASO 1: Solo captura la foto y la ubicación. NO sube a Drive.
  /// Retorna null si el usuario cancela la cámara.
  static Future<CapturaFotoResult?> tomarFoto() async {
    try {
      final Position? ubicacion = await GeolocationService.obtenerUbicacion();

      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 40,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (foto == null) return null;

      return CapturaFotoResult(
        fotoPath: foto.path,
        xFile: foto,
        ubicacion: ubicacion,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// PASO 2: Sube el XFile capturado a Google Drive.
  /// Retorna [SubidaDriveResult] con estado y URL o mensaje de error.
  static Future<SubidaDriveResult> subirFotoADrive(XFile foto) async {
    try {
      final String? url = await _subirArchivo(
        archivo: foto,
        projectId: 'fotos_casos',
        tipo: 'foto',
      );

      if (url != null) {
        return SubidaDriveResult.ok(url);
      }
      return const SubidaDriveResult.error(
          'No se pudo subir la foto al servidor. Intenta de nuevo.');
    } catch (e) {
      return SubidaDriveResult.error('Error subiendo foto: $e');
    }
  }

  /// Elimina el archivo local de una foto capturada.
  /// Usar cuando la subida a Drive falla y se quiere limpiar.
  static Future<void> eliminarFotoLocal(String? fotoPath) async {
    if (fotoPath == null) return;
    try {
      final file = File(fotoPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Si no se puede eliminar, no es crítico
    }
  }

  /// Convertir firma a base64
  static String firmaToBase64(Uint8List firmaBytes) {
    return base64Encode(firmaBytes);
  }

  /// Decodificar base64 a bytes
  static Uint8List base64ToFirma(String base64String) {
    return base64Decode(base64String);
  }

  /// Subir firma del cliente (bytes PNG) a Google Drive.
  /// Retorna [SubidaDriveResult] con estado y URL o mensaje de error.
  static Future<SubidaDriveResult> subirFirmaADrive({
    required Uint8List firmaBytes,
    required String nombre,
  }) async {
    try {
      final String base64String = base64Encode(firmaBytes);

      final Map<String, dynamic> requestData = {
        'projectId': 'fotos_casos',
        'base64': base64String,
        'mimeType': 'image/png',
        'name': '${nombre}_${DateTime.now().millisecondsSinceEpoch}.png',
        'tipo': 'firma_cliente',
      };

      final response = await http
          .post(
            Uri.parse(_scriptUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0',
            },
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 60));

      // Intentar JSON directo
      final urlFromJson = _extraerUrlDeJson(response.body);
      if (urlFromJson != null) {
        return SubidaDriveResult.ok(urlFromJson);
      }

      // Seguir redirect si aplica
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = _extraerRedirectUrl(response.body);
        if (redirectUrl != null) {
          final redirectResponse = await http
              .get(
                Uri.parse(redirectUrl),
                headers: {
                  'User-Agent': 'Mozilla/5.0',
                  'Accept': 'application/json'
                },
              )
              .timeout(const Duration(seconds: 30));
          final urlFromRedirect = _extraerUrlDeJson(redirectResponse.body);
          if (urlFromRedirect != null) {
            return SubidaDriveResult.ok(urlFromRedirect);
          }
        }
      }

      return const SubidaDriveResult.error(
          'No se pudo subir la firma al servidor');
    } catch (e) {
      return SubidaDriveResult.error('Error subiendo firma: $e');
    }
  }

  /// PASO 1 (galería): Solo selecciona la foto. NO sube a Drive.
  /// Retorna null si el usuario cancela.
  static Future<CapturaFotoResult?> seleccionarFotoGaleria() async {
    try {
      final Position? ubicacion = await GeolocationService.obtenerUbicacion();

      final XFile? foto = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (foto == null) return null;

      return CapturaFotoResult(
        fotoPath: foto.path,
        xFile: foto,
        ubicacion: ubicacion,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MÉTODOS PRIVADOS
  // ═══════════════════════════════════════════════════════════════════

  /// Subir archivo (foto) a Google Drive CON MANEJO DE REDIRECTS
  static Future<String?> _subirArchivo({
    required XFile archivo,
    required String projectId,
    required String tipo,
  }) async {
    try {
      final List<int> bytes = await archivo.readAsBytes();
      final String base64String = base64Encode(bytes);

      final Map<String, dynamic> requestData = {
        'projectId': projectId,
        'base64': base64String,
        'mimeType': 'image/jpeg',
        'name': '${tipo}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'tipo': tipo,
      };

      final response = await http
          .post(
            Uri.parse(_scriptUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0',
            },
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 60));

      // Intentar parsear JSON primero sin importar el status code
      final String? urlFromJson = _extraerUrlDeJson(response.body);
      if (urlFromJson != null) return urlFromJson;

      // Si hay redirect, seguirlo
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = _extraerRedirectUrl(response.body);
        if (redirectUrl != null) {
          final redirectResponse = await http
              .get(
                Uri.parse(redirectUrl),
                headers: {
                  'User-Agent': 'Mozilla/5.0',
                  'Accept': 'application/json'
                },
              )
              .timeout(const Duration(seconds: 30));

          final String? urlFromRedirect =
              _extraerUrlDeJson(redirectResponse.body);
          if (urlFromRedirect != null) return urlFromRedirect;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Intenta extraer la URL del campo 'url' de un JSON. Retorna null si falla.
  static String? _extraerUrlDeJson(String body) {
    try {
      final trimmed = body.trim();
      if (!trimmed.startsWith('{')) return null;
      final Map<String, dynamic> data = jsonDecode(trimmed);
      final url = data['url'];
      if (url != null && url.toString().isNotEmpty) return url.toString();
    } catch (_) {}
    return null;
  }

  /// Extrae la URL de redirect del HTML del Apps Script (patrón HREF="...")
  static String? _extraerRedirectUrl(String html) {
    final match1 =
        RegExp(r'HREF="([^"]+)"', caseSensitive: false).firstMatch(html);
    if (match1 != null) return match1.group(1)?.replaceAll('&amp;', '&');
    final match2 =
        RegExp(r"href='([^']+)'", caseSensitive: false).firstMatch(html);
    if (match2 != null) return match2.group(1)?.replaceAll('&amp;', '&');
    return null;
  }
}