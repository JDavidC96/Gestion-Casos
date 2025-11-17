import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'camera_service.dart';

class LogoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final ImagePicker _picker = ImagePicker();
  
  /// Subir logo del grupo
  static Future<String?> uploadLogo(XFile image, String grupoId) async {
    try {
      print('🔄 Subiendo logo para grupo: $grupoId');
      
      // Seleccionar imagen de galería directamente
      final XFile? selectedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (selectedImage != null) {
        // Usar CameraService para subir a Drive
        final result = await CameraService.seleccionarFotoGaleria();
        if (result?['driveUrl'] != null) {
          await _firestore
              .collection('grupos')
              .doc(grupoId)
              .update({
            'logoUrl': result!['driveUrl'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          print('✅ Logo subido exitosamente');
          return result['driveUrl'];
        }
      }
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
  static bool canManageLogo(String? userGrupoId, String targetGrupoId, String userRole) {
    return userRole == 'super_admin' || 
           (userRole == 'admin' && userGrupoId == targetGrupoId);
  }
}