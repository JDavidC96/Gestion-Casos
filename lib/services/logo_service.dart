import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_service.dart';

class LogoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Subir logo del grupo.
  /// Abre el selector de galería, sube a Drive y guarda la URL en Firestore.
  static Future<String?> uploadLogo(String grupoId) async {
    try {
      print('🔄 Subiendo logo para grupo: $grupoId');

      // PASO 1: Seleccionar imagen de galería
      final result = await CameraService.seleccionarFotoGaleria();

      if (result == null || result['xFile'] == null) {
        print('ℹ️ No se seleccionó ninguna imagen.');
        return null;
      }

      // PASO 2: Subir a Drive (igual que las fotos de casos)
      final XFile xFile = result['xFile'] as XFile;
      print('📤 Subiendo logo a Drive...');
      final String? driveUrl = await CameraService.subirFotoADrive(xFile);

      if (driveUrl == null) {
        print('❌ No se pudo subir el logo a Drive.');
        return null;
      }

      // PASO 3: Guardar URL en Firestore
      await _firestore
          .collection('grupos')
          .doc(grupoId)
          .update({
        'logoUrl': driveUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Logo subido exitosamente: $driveUrl');
      return driveUrl;
    } catch (e) {
      print('❌ Error subiendo logo: $e');
      rethrow;
    }
  }

  /// Eliminar logo del grupo
  static Future<void> deleteLogo(String grupoId) async {
    try {
      await _firestore
          .collection('grupos')
          .doc(grupoId)
          .update({
        'logoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Logo eliminado exitosamente');
    } catch (e) {
      print('❌ Error eliminando logo: $e');
      rethrow;
    }
  }

  /// Validar permisos para gestionar logo
  static bool canManageLogo(
      String? userGrupoId, String targetGrupoId, String userRole) {
    return userRole == 'super_admin' ||
        (userRole == 'admin' && userGrupoId == targetGrupoId);
  }
}