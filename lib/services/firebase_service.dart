// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // GoogleSignIn
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // ============= AUTENTICACIÓN =============
  
  static Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      print('Error en login: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  static Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  // Método para recuperación de contraseña
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error enviando email de recuperación: $e');
      rethrow;
    }
  }

  // Método MODIFICADO para inicio de sesión con Google
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'google-signin-cancelled',
          message: 'El inicio de sesión con Google fue cancelado',
        );
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Verificar si el usuario ya existe en Firestore
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          // Usuario NO existe - retornar datos para registro
          return {
            'needsRegistration': true,
            'user': user,
            'googleUser': googleUser,
            'email': user.email,
            'displayName': user.displayName ?? googleUser.displayName,
            'photoURL': user.photoURL ?? googleUser.photoUrl,
          };
        } else {
          // Usuario EXISTE - actualizar último login
          await _firestore.collection('users').doc(user.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
          return {
            'needsRegistration': false,
            'user': user,
          };
        }
      }

      return null;
    } catch (e) {
      print('Error en login con Google: $e');
      rethrow;
    }
  }

  // Método para completar registro con Google
  static Future<void> completeGoogleRegistration(
    String userId,
    String cedula,
    String displayName,
    String email,
    String? firmaBase64,
    String? grupoId,
    String? grupoNombre,
    String role,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'cedula': cedula,
        'displayName': displayName,
        'email': email,
        'firmaBase64': firmaBase64,
        'grupoId': grupoId,
        'grupoNombre': grupoNombre,
        'role': role,
        'provider': 'google',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error completando registro con Google: $e');
      rethrow;
    }
  }

  // Método para cerrar sesión de Google
  static Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
  }

  // Crear super usuario (solo primera vez)
  static Future<User?> createSuperUser(String email, String password, String displayName) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Guardar información del usuario
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'displayName': displayName,
        'role': 'super_admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return credential.user;
    } catch (e) {
      print('Error creando super usuario: $e');
      rethrow;
    }
  }

  // Verificar si es super admin
  static Future<bool> isSuperAdmin() async {
    final user = getCurrentUser();
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['role'] == 'super_admin';
  }

  // ============= EMPRESAS =============
  
  static Future<String> createEmpresa(Map<String, dynamic> empresaData) async {
    final user = getCurrentUser();
    empresaData['createdBy'] = user?.uid;
    empresaData['createdAt'] = FieldValue.serverTimestamp();
    
    final doc = await _firestore.collection('empresas').add(empresaData);
    return doc.id;
  }

  static Future<void> updateEmpresa(String empresaId, Map<String, dynamic> data) async {
    await _firestore.collection('empresas').doc(empresaId).update(data);
  }

  static Future<void> deleteEmpresa(String empresaId) async {
    await _firestore.collection('empresas').doc(empresaId).delete();
  }

  static Stream<QuerySnapshot> getEmpresasStream() {
    return _firestore.collection('empresas').orderBy('nombre').snapshots();
  }

  // NUEVO: Obtener empresas por grupo
  static Stream<QuerySnapshot> getEmpresasPorGrupoStream(String? grupoId) {
    if (grupoId == null) {
      return _firestore.collection('empresas').orderBy('nombre').snapshots();
    }
    return _firestore
        .collection('empresas')
        .where('grupoId', isEqualTo: grupoId)
        .orderBy('nombre')
        .snapshots();
  }

  // NUEVO: Crear empresa con grupo
  static Future<String> addEmpresaConGrupo(
    String nombre, 
    String nit, 
    String iconName,
    String? grupoId,
    String? grupoNombre,
  ) async {
    final user = getCurrentUser();
    final empresaData = {
      'nombre': nombre,
      'nit': nit,
      'iconName': iconName,
      'grupoId': grupoId,
      'grupoNombre': grupoNombre,
      'createdBy': user?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };
    
    final doc = await _firestore.collection('empresas').add(empresaData);
    return doc.id;
  }

  // ============= CENTROS DE TRABAJO =============
  
  static Future<String> createCentroTrabajo(Map<String, dynamic> centroData) async {
    // SIN campos de fecha - solo datos simples
    final doc = await _firestore.collection('centros_trabajo').add(centroData);
    return doc.id;
  }

  static Future<void> updateCentroTrabajo(String centroId, Map<String, dynamic> data) async {
    // SIN campos de fecha - solo datos simples
    await _firestore.collection('centros_trabajo').doc(centroId).update(data);
  }

  static Future<void> deleteCentroTrabajo(String centroId) async {
    await _firestore.collection('centros_trabajo').doc(centroId).delete();
  }

  static Stream<QuerySnapshot> getCentrosPorEmpresaStream(String empresaId) {
    return _firestore
        .collection('centros_trabajo')
        .where('empresaId', isEqualTo: empresaId)
        .orderBy('nombre')
        .snapshots();
  }

  // NUEVO: Obtener centros por grupo
  static Stream<QuerySnapshot> getCentrosPorGrupoStream(String? grupoId) {
    if (grupoId == null) {
      return _firestore.collection('centros_trabajo').orderBy('nombre').snapshots();
    }
    return _firestore
        .collection('centros_trabajo')
        .where('grupoId', isEqualTo: grupoId)
        .orderBy('nombre')
        .snapshots();
  }

  // ============= CASOS =============
  
  static Future<String> createCaso(Map<String, dynamic> casoData) async {
    casoData['createdAt'] = FieldValue.serverTimestamp();
    final doc = await _firestore.collection('casos').add(casoData);
    return doc.id;
  }

  static Future<void> updateCaso(String casoId, Map<String, dynamic> data) async {
    await _firestore.collection('casos').doc(casoId).update(data);
  }

  static Future<void> deleteCaso(String casoId) async {
    await _firestore.collection('casos').doc(casoId).delete();
  }

  static Stream<QuerySnapshot> getCasosPorEmpresaStream(String empresaId) {
    return _firestore
        .collection('casos')
        .where('empresaId', isEqualTo: empresaId)
        .orderBy('fechaCreacion', descending: true)
        .snapshots();
  }

  // NUEVO: Obtener casos por grupo
  static Stream<QuerySnapshot> getCasosPorGrupoStream(String? grupoId) {
    if (grupoId == null) {
      return _firestore.collection('casos').orderBy('fechaCreacion', descending: true).snapshots();
    }
    return _firestore
        .collection('casos')
        .where('grupoId', isEqualTo: grupoId)
        .orderBy('fechaCreacion', descending: true)
        .snapshots();
  }

  // NUEVO: Obtener casos por grupo (para reporte)
  static Future<List<Map<String, dynamic>>> getCasosByGroup(String grupoId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('casos')
          .where('grupoId', isEqualTo: grupoId)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {...data, 'id': doc.id};
      }).toList();
    } catch (e) {
      print('Error getting casos by group: $e');
      return [];
    }
  }

  static Future<void> cerrarCaso(String casoId) async {
    await _firestore.collection('casos').doc(casoId).update({
      'cerrado': true,
      'fechaCierre': FieldValue.serverTimestamp(),
    });
  }

  // ============= ACTUALIZAR ESTADO ABIERTO =============
  
  static Future<void> updateEstadoAbierto(String casoId, Map<String, dynamic> estadoAbiertoData) async {
    await _firestore.collection('casos').doc(casoId).update({
      'estadoAbierto': estadoAbiertoData,
    });
  }

  // ============= ACTUALIZAR ESTADO CERRADO =============
  
  static Future<void> updateEstadoCerrado(String casoId, Map<String, dynamic> estadoCerradoData) async {
    await _firestore.collection('casos').doc(casoId).update({
      'estadoCerrado': estadoCerradoData,
      'cerrado': true,
      'fechaCierre': FieldValue.serverTimestamp(),
    });
  }

  // ============= OBTENER CASO POR ID =============
  
  static Future<DocumentSnapshot> getCasoById(String casoId) async {
    return await _firestore.collection('casos').doc(casoId).get();
  }

  // ============= STREAM DE UN CASO ESPECÍFICO =============
  
  static Stream<DocumentSnapshot> getCasoStream(String casoId) {
    return _firestore.collection('casos').doc(casoId).snapshots();
  }

  // ============= STORAGE (FOTOS Y FIRMAS) =============
  
  static Future<String> uploadFoto(File foto, String casoId, String tipo) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('casos/$casoId/$tipo/$fileName');
      
      final uploadTask = await ref.putFile(foto);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error subiendo foto: $e');
      rethrow;
    }
  }

  static Future<String> uploadFirma(List<int> firmaBytes, String casoId, String tipo) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = _storage.ref().child('casos/$casoId/firmas_$tipo/$fileName');
      
      final uploadTask = await ref.putData(
        firmaBytes as dynamic,
        SettableMetadata(contentType: 'image/png'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error subiendo firma: $e');
      rethrow;
    }
  }

  static Future<void> deleteFotoOFirma(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('Error eliminando archivo: $e');
    }
  }

  // ============= UTILIDADES =============
  
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data();
  }

  static Future<int> contarCasosPorEmpresa(String empresaId, {bool? cerrados}) async {
    Query query = _firestore
        .collection('casos')
        .where('empresaId', isEqualTo: empresaId);
    
    if (cerrados != null) {
      query = query.where('cerrado', isEqualTo: cerrados);
    }
    
    final snapshot = await query.get();
    return snapshot.docs.length;
  }
}