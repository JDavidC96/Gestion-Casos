// lib/services/logo_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'camera_service.dart';

/// Resultado de operación con logo.
class LogoResult {
  final bool exitoso;
  final String? url;
  final String mensaje;

  const LogoResult.ok({this.url, required this.mensaje})
      : exitoso = true;

  const LogoResult.error(this.mensaje)
      : exitoso = false,
        url = null;
}

class LogoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Subir logo del grupo.
  /// Abre el selector de galería, sube a Drive y guarda la URL en Firestore.
  /// Retorna [LogoResult] con el estado de la operación.
  static Future<LogoResult> uploadLogo(String grupoId) async {
    try {
      // PASO 1: Seleccionar imagen de galería
      final result = await CameraService.seleccionarFotoGaleria();

      if (result == null) {
        return const LogoResult.error('No se seleccionó ninguna imagen');
      }

      // PASO 2: Subir a Drive
      final subida = await CameraService.subirFotoADrive(result.xFile);

      if (!subida.exitoso || subida.url == null) {
        return LogoResult.error(subida.mensaje);
      }

      // PASO 3: Guardar URL en Firestore
      await _firestore.collection('grupos').doc(grupoId).update({
        'logoUrl': subida.url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return LogoResult.ok(
        url: subida.url,
        mensaje: 'Logo actualizado correctamente',
      );
    } catch (e) {
      return LogoResult.error('Error subiendo logo: $e');
    }
  }

  /// Eliminar logo del grupo.
  /// Retorna [LogoResult] con el estado de la operación.
  static Future<LogoResult> deleteLogo(String grupoId) async {
    try {
      await _firestore.collection('grupos').doc(grupoId).update({
        'logoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return const LogoResult.ok(mensaje: 'Logo eliminado correctamente');
    } catch (e) {
      return LogoResult.error('Error eliminando logo: $e');
    }
  }

  /// Validar permisos para gestionar logo
  static bool canManageLogo(
      String? userGrupoId, String targetGrupoId, String userRole) {
    return userRole == 'super_admin' ||
        (userRole == 'admin' && userGrupoId == targetGrupoId);
  }
}