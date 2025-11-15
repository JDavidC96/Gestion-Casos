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
  static const String _scriptUrl = 'https://script.google.com/macros/s/AKfycbysQi3O-gCX_whDHg0Qq6XiUQ1eqmHUl6xHUIMLFRf5Uwi7uLDzqLzLoBM9H979a8KI/exec';

  /// Tomar foto con cámara y subirla a Google Drive
  static Future<Map<String, dynamic>?> tomarFoto() async {
    try {
      // Obtener ubicación primero
      final Position? ubicacion = await GeolocationService.obtenerUbicacion();
      
      // Tomar foto
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );

      if (foto != null) {
        print('📸 Foto capturada: ${foto.path}');
        
        // Subir a Google Drive
        String? driveUrl;
        try {
          driveUrl = await _subirArchivo(
            archivo: foto,
            projectId: 'fotos_casos',
            tipo: 'foto',
          );
          print('✅ URL generada: $driveUrl');
        } catch (e) {
          print('⚠️ Error subiendo a Drive: $e');
        }

        return {
          'fotoPath': foto.path,
          'ubicacion': ubicacion,
          'driveUrl': driveUrl,
          'fecha': DateTime.now(),
        };
      }
    } catch (e) {
      print('Error tomando foto: $e');
      rethrow;
    }
    return null;
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
      // Leer archivo como bytes
      final List<int> bytes = await archivo.readAsBytes();
      
      // Convertir a base64
      final String base64String = base64Encode(bytes);
      
      // Preparar datos para enviar
      final Map<String, dynamic> requestData = {
        'projectId': projectId,
        'base64': base64String,
        'mimeType': 'image/jpeg',
        'name': '${tipo}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'tipo': tipo,
      };

      print('📤 Subiendo archivo a Drive...');
      print('   Tamaño: ${bytes.length} bytes');

      // Enviar a Google Apps Script con headers adicionales
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0',
        },
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 60));

      print('📦 Respuesta - Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          final url = responseData['url'];
          print('✅ URL de Drive: $url');
          return url;
        } else {
          print('❌ Error en respuesta: ${responseData['error']}');
          return null;
        }
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // MANEJO DE REDIRECT
        print('🔄 Redirect detectado (${response.statusCode}), extrayendo URL...');
        
        final redirectMatch = RegExp(r'HREF="([^"]+)"').firstMatch(response.body);
        if (redirectMatch != null) {
          var redirectUrl = redirectMatch.group(1)?.replaceAll('&amp;', '&');
          print('🔗 URL de redirect encontrada');
          
          if (redirectUrl != null) {
            try {
              print('📥 Siguiendo redirect...');
              final redirectResponse = await http.get(
                Uri.parse(redirectUrl),
                headers: {
                  'User-Agent': 'Mozilla/5.0',
                  'Accept': 'application/json',
                }
              ).timeout(const Duration(seconds: 30));
              
              print('📦 Respuesta después de redirect - Status: ${redirectResponse.statusCode}');
              
              if (redirectResponse.statusCode == 200) {
                try {
                  final Map<String, dynamic> responseData = jsonDecode(redirectResponse.body);
                  final String? driveUrl = responseData['url'];
                  
                  if (driveUrl != null && driveUrl.isNotEmpty) {
                    print('✅ Archivo subido exitosamente vía redirect!');
                    print('   URL: $driveUrl');
                    return driveUrl;
                  } else {
                    print('⚠️ Respuesta JSON sin URL');
                    print('   Response: ${responseData.toString()}');
                  }
                } catch (jsonError) {
                  print('❌ Error parseando JSON: $jsonError');
                  final bodyPreview = redirectResponse.body.length > 500 
                      ? redirectResponse.body.substring(0, 500) 
                      : redirectResponse.body;
                  print('   Body: $bodyPreview');
                }
              } else {
                print('❌ Error en redirect response: ${redirectResponse.statusCode}');
              }
            } catch (redirectError) {
              print('❌ Error siguiendo redirect: $redirectError');
            }
          }
        } else {
          print('❌ No se pudo extraer URL de redirect del HTML');
        }
        
        return null;
      } else {
        print('❌ Error HTTP ${response.statusCode}');
        final bodyPreview = response.body.length > 200 
            ? response.body.substring(0, 200) 
            : response.body;
        print('   Body: $bodyPreview');
        return null;
      }
    } catch (e) {
      print('❌ Error en _subirArchivo: $e');
      return null;
    }
  }

  /// Seleccionar foto de galería
  static Future<Map<String, dynamic>?> seleccionarFotoGaleria() async {
    try {
      final Position? ubicacion = await GeolocationService.obtenerUbicacion();
      
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (foto != null) {
        final String? driveUrl = await _subirArchivo(
          archivo: foto,
          projectId: 'fotos_casos',
          tipo: 'foto_galeria',
        );

        return {
          'fotoPath': foto.path,
          'ubicacion': ubicacion,
          'driveUrl': driveUrl,
          'fecha': DateTime.now(),
        };
      }
    } catch (e) {
      print('Error seleccionando foto de galería: $e');
      rethrow;
    }
    return null;
  }
}