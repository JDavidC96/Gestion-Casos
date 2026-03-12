// lib/services/firebase_service.dart
//
// ═══════════════════════════════════════════════════════════════════
//  NUEVA ESTRUCTURA JERÁRQUICA DE FIRESTORE
// ───────────────────────────────────────────────────────────────────
//  Colecciones raíz (globales):
//    • grupos              → grupos/{grupoId}
//    • solicitudes_grupos  → solicitudes_grupos/{solicitudId}
//    • users               → users/{uid}   (sigue siendo global para auth)
//
//  Sub-colecciones por grupo:
//    grupos/{grupoId}/
//      empresas/{empresaId}/
//        centros_trabajo/{centroId}/
//          casos/{casoId}
//
//  Helpers de paths (para no repetir strings en toda la app):
//    _empresasRef(grupoId)
//    _centrosRef(grupoId, empresaId)
//    _casosRef(grupoId, empresaId, centroId)
//    _casoDoc(grupoId, empresaId, centroId, casoId)
// ═══════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // ─── Path helpers ────────────────────────────────────────────────────────

  /// grupos/{grupoId}/empresas
  static CollectionReference _empresasRef(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('empresas');

  /// grupos/{grupoId}/empresas/{empresaId}/centros_trabajo
  static CollectionReference _centrosRef(String grupoId, String empresaId) =>
      _empresasRef(grupoId).doc(empresaId).collection('centros_trabajo');

  /// grupos/{grupoId}/empresas/{empresaId}/centros_trabajo/{centroId}/casos
  static CollectionReference _casosRef(
          String grupoId, String empresaId, String centroId) =>
      _centrosRef(grupoId, empresaId).doc(centroId).collection('casos');

  /// Documento individual de caso
  static DocumentReference _casoDoc(
          String grupoId, String empresaId, String centroId, String casoId) =>
      _casosRef(grupoId, empresaId, centroId).doc(casoId);

  // ═══════════════════════════════════════════════════════════════════
  //  AUTENTICACIÓN
  // ═══════════════════════════════════════════════════════════════════

  static Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return credential.user;
    } catch (e) {
      print('Error en login: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async => await _auth.signOut();

  static User? getCurrentUser() => _auth.currentUser;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error enviando email de recuperación: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'google-signin-cancelled',
          message: 'El inicio de sesión con Google fue cancelado',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          return {
            'needsRegistration': true,
            'user': user,
            'googleUser': googleUser,
            'email': user.email,
            'displayName': user.displayName ?? googleUser.displayName,
            'photoURL': user.photoURL ?? googleUser.photoUrl,
          };
        } else {
          await _db.collection('users').doc(user.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
          return {'needsRegistration': false, 'user': user};
        }
      }
      return null;
    } catch (e) {
      print('Error en login con Google: $e');
      rethrow;
    }
  }

  static Future<void> completeGoogleRegistration(
    String userId,
    String cedula,
    String displayName,
    String email,
    String? firmaUrl,
    String? grupoId,
    String? grupoNombre,
    String role,
  ) async {
    try {
      await _db.collection('users').doc(userId).set({
        'uid': userId,
        'cedula': cedula,
        'displayName': displayName,
        'email': email,
        if (firmaUrl != null) 'firmaUrl': firmaUrl,
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

  static Future<void> signOutGoogle() async => await _googleSignIn.signOut();

  static Future<User?> createSuperUser(
      String email, String password, String displayName) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await _db.collection('users').doc(credential.user!.uid).set({
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

  static Future<bool> isSuperAdmin() async {
    final user = getCurrentUser();
    if (user == null) return false;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data()?['role'] == 'super_admin';
  }

  // ═══════════════════════════════════════════════════════════════════
  //  EMPRESAS  →  grupos/{grupoId}/empresas/{empresaId}
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todas las empresas de un grupo, ordenadas por nombre.
  static Stream<QuerySnapshot> getEmpresasPorGrupoStream(String grupoId) {
    return _empresasRef(grupoId).orderBy('nombre').snapshots();
  }

  /// Stream de empresas asignadas a un inspector (por lista de IDs).
  /// Firestore no permite queries por toda la colección si el rol solo
  /// tiene acceso a documentos específicos — esta función los trae uno a uno
  /// y los combina en un stream reactivo.
  static Stream<List<Map<String, dynamic>>> getEmpresasAsignadasStream(
      String grupoId, List<String> empresaIds) async* {
    if (empresaIds.isEmpty) {
      yield [];
      return;
    }
    // Escuchar cambios en cada empresa asignada y emitir la lista combinada
    yield* _empresasRef(grupoId)
        .where(FieldPath.documentId, whereIn: empresaIds)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {...data, 'id': doc.id};
            }).toList());
  }

  /// Versión Future (para reportes, conteos, etc.)
  static Future<QuerySnapshot> getEmpresasPorGrupo(String grupoId) async {
    return _empresasRef(grupoId).orderBy('nombre').get();
  }

  static Future<String> addEmpresaConGrupo(
    String nombre,
    String nit,
    String iconName,
    String grupoId,
    String grupoNombre,
  ) async {
    final user = getCurrentUser();
    final doc = await _empresasRef(grupoId).add({
      'nombre': nombre,
      'nit': nit,
      'iconName': iconName,
      'grupoId': grupoId,       // redundante pero útil para collectionGroup queries
      'grupoNombre': grupoNombre,
      'createdBy': user?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  static Future<void> updateEmpresa(
      String grupoId, String empresaId, Map<String, dynamic> data) async {
    await _empresasRef(grupoId).doc(empresaId).update(data);
  }

  static Future<void> deleteEmpresa(String grupoId, String empresaId) async {
    // Eliminar sub-colecciones primero (centros y sus casos)
    final centros = await _centrosRef(grupoId, empresaId).get();
    for (final c in centros.docs) {
      await _deleteCentroConCasos(grupoId, empresaId, c.id);
    }
    await _empresasRef(grupoId).doc(empresaId).delete();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CENTROS DE TRABAJO  →  .../empresas/{empresaId}/centros_trabajo
  // ═══════════════════════════════════════════════════════════════════

  static Stream<QuerySnapshot> getCentrosPorEmpresaStream(
      String grupoId, String empresaId) {
    return _centrosRef(grupoId, empresaId).orderBy('nombre').snapshots();
  }

  static Future<String> createCentroTrabajo(
      String grupoId, String empresaId, Map<String, dynamic> centroData) async {
    // Aseguramos que los IDs queden guardados en el documento
    centroData['grupoId'] = grupoId;
    centroData['empresaId'] = empresaId;
    final doc = await _centrosRef(grupoId, empresaId).add(centroData);
    return doc.id;
  }

  static Future<void> updateCentroTrabajo(String grupoId, String empresaId,
      String centroId, Map<String, dynamic> data) async {
    await _centrosRef(grupoId, empresaId).doc(centroId).update(data);
  }

  static Future<void> deleteCentroTrabajo(
      String grupoId, String empresaId, String centroId) async {
    await _deleteCentroConCasos(grupoId, empresaId, centroId);
  }

  /// Elimina un centro y todos sus casos (helper interno).
  static Future<void> _deleteCentroConCasos(
      String grupoId, String empresaId, String centroId) async {
    final casos = await _casosRef(grupoId, empresaId, centroId).get();
    for (final c in casos.docs) {
      await c.reference.delete();
    }
    await _centrosRef(grupoId, empresaId).doc(centroId).delete();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CASOS  →  .../centros_trabajo/{centroId}/casos
  // ═══════════════════════════════════════════════════════════════════

  static Stream<QuerySnapshot> getCasosPorCentroStream(
      String grupoId, String empresaId, String centroId) {
    return _casosRef(grupoId, empresaId, centroId)
        .orderBy('fechaCreacion', descending: true)
        .snapshots();
  }

  /// Obtiene TODOS los casos de una empresa (CollectionGroup no disponible
  /// en reglas, así que iteramos los centros). Útil para reportes.
  static Future<List<Map<String, dynamic>>> getCasosPorEmpresa(
      String grupoId, String empresaId) async {
    final centros = await _centrosRef(grupoId, empresaId).get();
    final resultados = <Map<String, dynamic>>[];

    for (final centro in centros.docs) {
      final casos =
          await _casosRef(grupoId, empresaId, centro.id).orderBy('fechaCreacion', descending: true).get();
      for (final caso in casos.docs) {
        final data = caso.data() as Map<String, dynamic>;
        resultados.add({
          ...data,
          'id': caso.id,
          'centroId': centro.id,
          'centroNombre': data['centroNombre'] ?? (centro.data() as Map)['nombre'] ?? '',
        });
      }
    }

    // Ordenar en memoria por fecha descendente
    resultados.sort((a, b) {
      final fa = (a['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final fb = (b['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return fb.compareTo(fa);
    });

    return resultados;
  }

  /// Versión para Stream de la pantalla de lista de casos.
  /// Retorna un Stream de un solo centro de trabajo.
  static Stream<QuerySnapshot> getCasosPorEmpresaStream(
      String grupoId, String empresaId, String centroId) {
    return _casosRef(grupoId, empresaId, centroId)
        .orderBy('fechaCreacion', descending: true)
        .snapshots();
  }

  static Future<String> createCaso(String grupoId, String empresaId,
      String centroId, Map<String, dynamic> casoData) async {
    casoData['createdAt'] = FieldValue.serverTimestamp();
    casoData['fechaCreacion'] = FieldValue.serverTimestamp();
    casoData['grupoId'] = grupoId;
    casoData['empresaId'] = empresaId;
    casoData['centroId'] = centroId;
    final doc = await _casosRef(grupoId, empresaId, centroId).add(casoData);
    return doc.id;
  }

  static Future<void> updateCaso(String grupoId, String empresaId,
      String centroId, String casoId, Map<String, dynamic> data) async {
    await _casoDoc(grupoId, empresaId, centroId, casoId).update(data);
  }

  static Future<void> deleteCaso(String grupoId, String empresaId,
      String centroId, String casoId) async {
    await _casoDoc(grupoId, empresaId, centroId, casoId).delete();
  }

  static Future<DocumentSnapshot> getCasoById(String grupoId, String empresaId,
      String centroId, String casoId) async {
    return await _casoDoc(grupoId, empresaId, centroId, casoId).get();
  }

  static Stream<DocumentSnapshot> getCasoStream(String grupoId,
      String empresaId, String centroId, String casoId) {
    return _casoDoc(grupoId, empresaId, centroId, casoId).snapshots();
  }

  static Future<void> cerrarCaso(String grupoId, String empresaId,
      String centroId, String casoId) async {
    await _casoDoc(grupoId, empresaId, centroId, casoId).update({
      'cerrado': true,
      'fechaCierre': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateEstadoAbierto(String grupoId, String empresaId,
      String centroId, String casoId, Map<String, dynamic> estadoAbiertoData) async {
    await _casoDoc(grupoId, empresaId, centroId, casoId).update({
      'estadoAbierto': estadoAbiertoData,
    });
  }

  static Future<void> updateEstadoCerrado(String grupoId, String empresaId,
      String centroId, String casoId, Map<String, dynamic> estadoCerradoData) async {
    await _casoDoc(grupoId, empresaId, centroId, casoId).update({
      'estadoCerrado': estadoCerradoData,
      'cerrado': true,
      'fechaCierre': FieldValue.serverTimestamp(),
    });
  }

  /// Conteo rápido de casos por centro (abiertos, cerrados o todos).
  static Future<int> contarCasosPorCentro(
    String grupoId,
    String empresaId,
    String centroId, {
    bool? cerrados,
  }) async {
    Query query = _casosRef(grupoId, empresaId, centroId);
    if (cerrados != null) {
      query = query.where('cerrado', isEqualTo: cerrados);
    }
    final snap = await query.get();
    return snap.docs.length;
  }

  /// Conteo de casos en TODA la empresa iterando centros.
  static Future<int> contarCasosPorEmpresa(
    String grupoId,
    String empresaId, {
    bool? cerrados,
  }) async {
    final centros = await _centrosRef(grupoId, empresaId).get();
    int total = 0;
    for (final c in centros.docs) {
      total += await contarCasosPorCentro(grupoId, empresaId, c.id,
          cerrados: cerrados);
    }
    return total;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STORAGE (fotos y firmas)
  // ═══════════════════════════════════════════════════════════════════

  static Future<String> uploadFoto(
      File foto, String grupoId, String empresaId, String centroId,
      String casoId, String tipo) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(
          'grupos/$grupoId/empresas/$empresaId/centros/$centroId/casos/$casoId/$tipo/$fileName');
      final uploadTask = await ref.putFile(foto);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error subiendo foto: $e');
      rethrow;
    }
  }

  static Future<String> uploadFirma(List<int> firmaBytes, String grupoId,
      String empresaId, String centroId, String casoId, String tipo) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = _storage.ref().child(
          'grupos/$grupoId/empresas/$empresaId/centros/$centroId/casos/$casoId/firmas_$tipo/$fileName');
      final uploadTask = await ref.putData(
        firmaBytes as dynamic,
        SettableMetadata(contentType: 'image/png'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error subiendo firma: $e');
      rethrow;
    }
  }

  static Future<void> deleteFotoOFirma(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      print('Error eliminando archivo: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  UTILIDADES
  // ═══════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data() as Map<String, dynamic>?;
  }

  /// Obtiene todos los casos de un grupo (para reportes globales).
  static Future<List<Map<String, dynamic>>> getCasosByGroup(
      String grupoId) async {
    final empresas = await _empresasRef(grupoId).get();
    final resultados = <Map<String, dynamic>>[];

    for (final empresa in empresas.docs) {
      final casosEmpresa =
          await getCasosPorEmpresa(grupoId, empresa.id);
      resultados.addAll(casosEmpresa);
    }
    return resultados;
  }

  /// Returns real [QueryDocumentSnapshot] objects for all cases in an empresa.
  /// Use this when calling ReportService methods that expect QueryDocumentSnapshot.
  static Future<List<QueryDocumentSnapshot>> getCasosDocsParaReporte(
      String grupoId, String empresaId) async {
    final centros = await _centrosRef(grupoId, empresaId).get();
    final resultados = <QueryDocumentSnapshot>[];
    for (final centro in centros.docs) {
      final casos = await _casosRef(grupoId, empresaId, centro.id).get();
      resultados.addAll(casos.docs);
    }
    return resultados;
  }
}