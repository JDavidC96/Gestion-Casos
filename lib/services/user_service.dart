// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Crear usuario en Authentication y Firestore
  static Future<AppUser?> createUser({
    required String email,
    required String password,
    required String cedula,
    required String displayName,
    required String role,
    String? firmaBase64,
    String? grupoId,
    String? grupoNombre,
    Map<String, dynamic>? configInterfaz,
  }) async {
    try {
      // Crear usuario en Authentication
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User user = userCredential.user!;
      
      // Actualizar display name en Authentication
      await user.updateDisplayName(displayName);

      // Crear documento en Firestore
      final AppUser newUser = AppUser(
        uid: user.uid,
        cedula: cedula,
        displayName: displayName,
        email: email,
        role: role,
        firmaBase64: firmaBase64,
        grupoId: grupoId,
        grupoNombre: grupoNombre,
        createdAt: DateTime.now(),
        configInterfaz: configInterfaz,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(newUser.toMap());

      return newUser;
    } catch (e) {
      print('Error creando usuario: $e');
      rethrow;
    }
  }

  // Obtener todos los usuarios (solo para super_admin)
  static Stream<QuerySnapshot> getUsersStream() {
    return _firestore.collection('users').snapshots();
  }

  // Obtener usuarios por grupo (para admin)
  static Stream<QuerySnapshot> getUsersByGroupStream(String grupoId) {
    return _firestore
        .collection('users')
        .where('grupoId', isEqualTo: grupoId)
        .snapshots();
  }

  // Actualizar usuario
  static Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    await _firestore.collection('users').doc(uid).update(updates);
  }

  // Eliminar usuario
  static Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
    // Solo eliminar de Authentication si es el usuario actual
    if (_auth.currentUser?.uid == uid) {
      await _auth.currentUser!.delete();
    }
  }

  // Obtener grupos (para super_admin)
  static Stream<QuerySnapshot> getGruposStream() {
    return _firestore.collection('grupos').snapshots();
  }

  // Crear grupo
  static Future<void> createGrupo(String nombre, String descripcion) async {
    await _firestore.collection('grupos').add({
      'nombre': nombre,
      'descripcion': descripcion,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Actualizar grupo
  static Future<void> updateGrupo(String groupId, Map<String, dynamic> updates) async {
    await _firestore.collection('grupos').doc(groupId).update(updates);
  }

  // Eliminar grupo y sus usuarios
  static Future<void> deleteGrupo(String groupId) async {
    // Eliminar grupo
    await _firestore.collection('grupos').doc(groupId).delete();
    
    // Eliminar usuarios del grupo
    final usersSnapshot = await _firestore
        .collection('users')
        .where('grupoId', isEqualTo: groupId)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in usersSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Obtener configuración de interfaz por grupo
  static Future<Map<String, dynamic>?> getConfigInterfaz(String grupoId) async {
    final doc = await _firestore.collection('grupos').doc(grupoId).get();
    return doc.data()?['configInterfaz'] as Map<String, dynamic>?;
  }

  // Obtener usuario por ID
  static Future<AppUser?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return AppUser.fromMap(uid, doc.data()!);
    }
    return null;
  }
}