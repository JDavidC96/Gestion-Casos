import 'package:cloud_firestore/cloud_firestore.dart';
import 'camera_service.dart';

class LogoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Subir logo del grupo.
  /// Abre el selector de galería UNA sola vez, sube a Drive y guarda la URL en Firestore.
  static Future<String?> uploadLogo(String grupoId) async {
    try {
      print('🔄 Subiendo logo para grupo: $grupoId');

      // CameraService.seleccionarFotoGaleria() abre el picker y sube a Drive en un solo paso
      final result = await CameraService.seleccionarFotoGaleria();

      if (result?['driveUrl'] != null) {
        final url = result!['driveUrl'] as String;

        await _firestore
            .collection('grupos')
            .doc(grupoId)
            .update({
          'logoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Logo subido exitosamente: $url');
        return url;
      }

      print('ℹ️ No se seleccionó ninguna imagen.');
      return null;
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