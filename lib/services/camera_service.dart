// lib/services/camera_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'geolocation_service.dart';

class CameraService {
  static final ImagePicker _picker = ImagePicker();
  
  // URL de tu Google Apps Script
  static const String _scriptUrl = 'https://script.google.com/macros/s/AKfycbyEnp9do9mJT_90v7__UopJB0ne0ZpCHwXQyvG9DUN5I5j3LWN9heOt_2ief8o9iodu/exec';

  /// PASO 1: Solo captura la foto y la ubicación. NO sube a Drive.
  /// Retorna inmediatamente para que la UI pueda mostrar la preview.
  static Future<Map<String, dynamic>?> tomarFoto() async {
    try {
      final Position? ubicacion = await GeolocationService.obtenerUbicacion();

      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 40,   // reducido para no superar el límite de 1MB de Apps Script
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (foto != null) {
        print('📸 Foto capturada: ${foto.path}');
        return {
          'fotoPath': foto.path,
          'ubicacion': ubicacion,
          'driveUrl': null, // se rellena en subirFotoADrive()
          'fecha': DateTime.now(),
          'xFile': foto,   // pasamos el XFile para subirlo después
        };
      }
    } catch (e) {
      print('Error tomando foto: $e');
      rethrow;
    }
    return null;
  }

  /// PASO 2: Sube el XFile capturado a Google Drive y devuelve la URL.
  /// Llamar justo después de tomarFoto(), mostrando un loading en la UI.
  static Future<String?> subirFotoADrive(XFile foto) async {
    try {
      final String? url = await _subirArchivo(
        archivo: foto,
        projectId: 'fotos_casos',
        tipo: 'foto',
      );
      print('✅ URL generada: $url');
      return url;
    } catch (e) {
      print('⚠️ Error subiendo foto a Drive: $e');
      return null;
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

      print('📤 Subiendo archivo a Drive... (raw: ${bytes.length} bytes, base64: ${base64String.length} chars)');

      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0',
        },
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 60));

      print('📦 Status: ${response.statusCode}');
      print('📦 Body preview: ${response.body.substring(0, response.body.length.clamp(0, 300))}');

      // Intentar parsear JSON primero sin importar el status code
      final String? urlFromJson = _extraerUrlDeJson(response.body);
      if (urlFromJson != null) {
        print('✅ URL obtenida del body JSON: $urlFromJson');
        return urlFromJson;
      }

      // Si hay redirect, seguirlo
      if (response.statusCode == 302 || response.statusCode == 301) {
        print('🔄 Redirect detectado (${response.statusCode})');

        // Intentar extraer URL del HTML del redirect
        final redirectUrl = _extraerRedirectUrl(response.body);
        print('🔗 URL de redirect: $redirectUrl');

        if (redirectUrl != null) {
          final redirectResponse = await http.get(
            Uri.parse(redirectUrl),
            headers: {'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 30));

          print('📦 Redirect status: ${redirectResponse.statusCode}');
          print('📦 Redirect body: ${redirectResponse.body.substring(0, redirectResponse.body.length.clamp(0, 300))}');

          final String? urlFromRedirect = _extraerUrlDeJson(redirectResponse.body);
          if (urlFromRedirect != null) {
            print('✅ URL obtenida del redirect: $urlFromRedirect');
            return urlFromRedirect;
          }
        }
      }

      print('❌ No se pudo obtener URL de Drive');
      return null;
    } catch (e) {
      print('❌ Error en _subirArchivo: $e');
      return null;
    }
  }

  /// Intenta extraer la URL del campo 'url' de un JSON. Retorna null si falla.
  static String? _extraerUrlDeJson(String body) {
    try {
      // Limpiar posibles caracteres extra al inicio/fin
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
    // Patrón principal: HREF="..."
    final match1 = RegExp(r'HREF="([^"]+)"', caseSensitive: false).firstMatch(html);
    if (match1 != null) return match1.group(1)?.replaceAll('&amp;', '&');
    // Patrón alternativo: href="..."
    final match2 = RegExp(r"href='([^']+)'", caseSensitive: false).firstMatch(html);
    if (match2 != null) return match2.group(1)?.replaceAll('&amp;', '&');
    return null;
  }

  /// Subir firma del cliente (bytes PNG) a Google Drive
  static Future<String?> subirFirmaADrive({
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

      print('📤 Subiendo firma cliente a Drive...');

      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0',
        },
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 60));

      // Intentar JSON directo
      final urlFromJson = _extraerUrlDeJson(response.body);
      if (urlFromJson != null) {
        print('✅ Firma subida: $urlFromJson');
        return urlFromJson;
      }

      // Seguir redirect si aplica
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = _extraerRedirectUrl(response.body);
        if (redirectUrl != null) {
          final redirectResponse = await http.get(
            Uri.parse(redirectUrl),
            headers: {'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 30));
          final urlFromRedirect = _extraerUrlDeJson(redirectResponse.body);
          if (urlFromRedirect != null) {
            print('✅ Firma subida vía redirect: $urlFromRedirect');
            return urlFromRedirect;
          }
        }
      }

      print('⚠️ No se pudo subir la firma cliente');
      return null;
    } catch (e) {
      print('❌ Error subiendo firma cliente: $e');
      return null;
    }
  }

  /// PASO 1 (galería): Solo selecciona la foto. NO sube a Drive.
  static Future<Map<String, dynamic>?> seleccionarFotoGaleria() async {
    try {
      final Position? ubicacion = await GeolocationService.obtenerUbicacion();

      final XFile? foto = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (foto != null) {
        return {
          'fotoPath': foto.path,
          'ubicacion': ubicacion,
          'driveUrl': null,
          'fecha': DateTime.now(),
          'xFile': foto,
        };
      }
    } catch (e) {
      print('Error seleccionando foto de galería: $e');
      rethrow;
    }
    return null;
  }
}