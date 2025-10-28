// services/camera_service.dart
import 'geolocation_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class CameraService {
  static final ImagePicker _picker = ImagePicker();

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
        return {
          'foto': XFile(foto.path),
          'ubicacion': ubicacion,
        };
      }
    } catch (e) {
      print('Error tomando foto: $e');
    }
    return null;
  }
}