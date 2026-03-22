// services/geolocation_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class GeolocationService {
  static Future<Position?> obtenerUbicacion() async {
    try {
      // Solicitar permisos
      final ubicacionStatus = await Permission.location.request();
      if (!ubicacionStatus.isGranted) {
        return null;
      }

      // Verificar si los servicios de ubicación están habilitados
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Verificar permisos específicos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Obtener ubicación
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      );

      return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
    } catch (e) {
      return null;
    }
  }

  static String formatearUbicacion(Position? ubicacion) {
    if (ubicacion == null) return 'No disponible';
    return '${ubicacion.latitude.toStringAsFixed(6)}, ${ubicacion.longitude.toStringAsFixed(6)}';
  }
}