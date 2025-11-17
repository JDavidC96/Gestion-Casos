import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  
  /// Validar permisos de administración (actualizado para nuevos roles)
  static Future<bool> validateAdminPermissions({
    required String userId,
    required String targetGrupoId,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final userRole = userData['role'] as String?;
      final userGrupoId = userData['grupoId'] as String?;
      
      return userRole == 'super_admin' || 
             userRole == 'superinspector' ||
             (userRole == 'admin' && userGrupoId == targetGrupoId);
    } catch (e) {
      print('❌ Error validando permisos: $e');
      return false;
    }
  }
  
  /// Obtener inspectores filtrados por grupo
  static Stream<QuerySnapshot> getFilteredInspectors({
    required String grupoId,
    bool includeSuperInspectors = false,
  }) {
    if (includeSuperInspectors) {
      return _firestore
          .collection('users')
          .where('grupoId', isEqualTo: grupoId)
          .where('role', whereIn: ['inspector', 'superinspector'])
          .snapshots();
    } else {
      return _firestore
          .collection('users')
          .where('grupoId', isEqualTo: grupoId)
          .where('role', isEqualTo: 'inspector')
          .snapshots();
    }
  }
  
  /// Contar inspectores en grupo
  static Stream<int> getInspectorCount(String grupoId) {
    return _firestore
        .collection('users')
        .where('grupoId', isEqualTo: grupoId)
        .where('role', whereIn: ['inspector', 'superinspector'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  /// Verificar si email ya existe en el grupo
  static Future<bool> isEmailInGroup(String email, String grupoId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .where('grupoId', isEqualTo: grupoId)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }
}