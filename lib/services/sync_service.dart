// lib/services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'connectivity_service.dart';
import 'offline_case_service.dart';
import 'firebase_service.dart';
import 'case_draft_service.dart';
import 'camera_service.dart';

/// Escucha cambios de conectividad y sube los casos offline pendientes
/// a Firestore en cuanto hay red disponible.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  StreamSubscription<bool>? _sub;
  bool _syncing = false;

  // Notificador para que la UI pueda reaccionar (p.ej. recargar la lista)
  final _doneController = StreamController<void>.broadcast();
  Stream<void> get onSyncDone => _doneController.stream;

  void init() {
    _sub = ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (online) {
        syncNow();
      }
    });

    // Intentar sincronizar al iniciar si ya hay red
    if (ConnectivityService.instance.isOnline) {
      syncNow();
    }
  }

  /// Sube todos los casos pendientes. Se puede llamar manualmente.
  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final pending = OfflineCaseService.instance.getPending();
      if (pending.isEmpty) return;

      debugPrint('🔄 SyncService: ${pending.length} casos pendientes');

      // Fase 1: Subir a Firestore y marcar sincronizados en Hive.
      // El firestoreId queda guardado en Hive para que _checkIfSynced()
      // pueda leerlo antes de que borremos la entrada.
      final syncedEntries = <_SyncedEntry>[];
      for (final caso in pending) {
        final entry = await _syncCase(caso);
        if (entry != null) syncedEntries.add(entry);
      }

      // Fase 2: Notificar la UI mientras los casos AÚN están en Hive.
      // _checkIfSynced() en case_detail_screen puede leer firestoreId aquí.
      if (syncedEntries.isNotEmpty) {
        _doneController.add(null);
        debugPrint('✅ SyncService: ${syncedEntries.length} casos sincronizados');
      }

      // Fase 3: Migrar drafts de offlineId → firestoreId y limpiar Hive
      // después de un breve delay para que la UI haya tenido tiempo
      // de reaccionar al onSyncDone.
      await Future.delayed(const Duration(seconds: 3));
      for (final entry in syncedEntries) {
        // Migrar draft: copiar de offlineId a firestoreId, luego borrar el viejo
        await _migrateDraft(entry.offlineId, entry.firestoreId);
        await OfflineCaseService.instance.deleteCase(entry.offlineId);
      }
    } catch (e) {
      debugPrint('❌ SyncService error: $e');
    } finally {
      _syncing = false;
    }
  }

  /// Sube un caso a Firestore y lo marca como sincronizado en Hive.
  /// Devuelve un _SyncedEntry si fue exitoso, null si falló.
  Future<_SyncedEntry?> _syncCase(Map<String, dynamic> caso) async {
    final offlineId = caso['offlineId'] as String;
    final grupoId = caso['grupoId'] as String? ?? '';
    final empresaId = caso['empresaId'] as String? ?? '';
    final centroId = caso['centroId'] as String? ?? '';

    if (grupoId.isEmpty || empresaId.isEmpty || centroId.isEmpty) {
      debugPrint('⚠️ SyncService: caso $offlineId sin IDs válidos, omitido');
      return null;
    }

    try {
      // Preparar datos para Firestore (sin campos de Hive)
      final firestoreData = Map<String, dynamic>.from(caso)
        ..remove('offlineId')
        ..remove('sincronizado')
        ..remove('creadoAt')
        ..remove('fotosLocales')
        ..remove('fotoLocalAbierto')
        ..remove('fotoLocalCerrado')
        ..remove('firestoreId');

      // ── Incorporar datos del draft (estadoAbierto) ───────────────────
      // El inspector pudo haber llenado descripción, nombre del cliente,
      // firma, etc. mientras estaba offline. Esos datos están solo en el
      // draft, no en el entry offline.
      final draft = await CaseDraftService.instance.getDraft(offlineId);
      if (draft != null) {
        await _mergeDraftIntoFirestoreData(
            firestoreData, draft, caso, grupoId, empresaId, centroId, offlineId);
      }

      // Subir foto de estado abierto si existe localmente (a Google Drive)
      final fotoLocalAbierto = caso['fotoLocalAbierto'] as String?;
      String? fotoAbiertoUrl;
      if (fotoLocalAbierto != null && !kIsWeb) {
        try {
          final file = File(fotoLocalAbierto);
          if (await file.exists()) {
            final xFile = XFile(fotoLocalAbierto);
            final subida = await CameraService.subirFotoADrive(xFile);
            if (subida.exitoso && subida.url != null) {
              fotoAbiertoUrl = subida.url;
              firestoreData['fotoAbiertoUrl'] = fotoAbiertoUrl;
            }
          }
        } catch (e) {
          debugPrint('⚠️ No se pudo subir foto abierto: $e');
        }
      }

      // Subir foto de estado cerrado si existe localmente
      final fotoLocalCerrado = caso['fotoLocalCerrado'] as String?;
      String? fotoCerradoUrl;
      if (fotoLocalCerrado != null && !kIsWeb) {
        try {
          final file = File(fotoLocalCerrado);
          if (await file.exists()) {
            final xFile = XFile(fotoLocalCerrado);
            final subida = await CameraService.subirFotoADrive(xFile);
            if (subida.exitoso && subida.url != null) {
              fotoCerradoUrl = subida.url;
              firestoreData['fotoCerradoUrl'] = fotoCerradoUrl;
            }
          }
        } catch (e) {
          debugPrint('⚠️ No se pudo subir foto cerrado: $e');
        }
      }

      // Si hay estadoAbierto y se subió foto, inyectar la URL ahí también
      final estadoAbierto = firestoreData['estadoAbierto'] as Map<String, dynamic>?;
      if (estadoAbierto != null && fotoAbiertoUrl != null) {
        estadoAbierto['fotoUrl'] = fotoAbiertoUrl;
      }

      // Si hay estadoCerrado y se subió foto cerrado, inyectar la URL
      final estadoCerrado = firestoreData['estadoCerrado'] as Map<String, dynamic>?;
      if (estadoCerrado != null && fotoCerradoUrl != null) {
        estadoCerrado['fotoUrl'] = fotoCerradoUrl;
      }

      // Crear el caso en Firestore
      final firestoreId = await FirebaseService.createCasoAndGetId(
          grupoId, empresaId, centroId, firestoreData);

      // Marcar como sincronizado — el firestoreId queda en Hive
      // hasta que syncNow() lo borre en la Fase 3
      await OfflineCaseService.instance.markSynced(
          offlineId, firestoreId: firestoreId);

      debugPrint('✅ Caso $offlineId → Firestore $firestoreId');
      return _SyncedEntry(offlineId: offlineId, firestoreId: firestoreId);
    } catch (e) {
      debugPrint('❌ Error sincronizando $offlineId: $e');
      return null;
    }
  }

  /// Incorpora los datos del draft al mapa que se subirá a Firestore.
  /// Construye el sub-mapa `estadoAbierto` con descripción, nivel de
  /// peligro, nombre del cliente, firma del cliente, recomendaciones, etc.
  Future<void> _mergeDraftIntoFirestoreData(
    Map<String, dynamic> firestoreData,
    Map<String, dynamic> draft,
    Map<String, dynamic> casoOriginal,
    String grupoId,
    String empresaId,
    String centroId,
    String offlineId,
  ) async {
    final descripcion = draft['descripcionHallazgo'] as String?;
    final nivelPeligro = draft['nivelPeligro'] as String?;
    final recomendaciones = draft['recomendacionesControl'] as String?;
    final nombreCliente = draft['nombreClienteAbierto'] as String?;
    final ubicacionTexto = draft['ubicacionTexto'] as String?;
    final fotoUrl = draft['fotoAbiertoUrl'] as String?;

    // Solo construir estadoAbierto si hay al menos un campo con datos
    final hayDatosAbierto = (descripcion != null && descripcion.isNotEmpty) ||
        (nombreCliente != null && nombreCliente.isNotEmpty) ||
        (recomendaciones != null && recomendaciones.isNotEmpty) ||
        fotoUrl != null;

    if (hayDatosAbierto) {
      final estadoAbierto = <String, dynamic>{
        if (descripcion != null && descripcion.isNotEmpty)
          'descripcionHallazgo': descripcion,
        if (nivelPeligro != null && nivelPeligro.isNotEmpty)
          'nivelPeligro': nivelPeligro,
        if (recomendaciones != null && recomendaciones.isNotEmpty)
          'recomendacionesControl': recomendaciones,
        if (ubicacionTexto != null && ubicacionTexto.isNotEmpty)
          'ubicacionTexto': ubicacionTexto,
        if (fotoUrl != null) 'fotoUrl': fotoUrl,
        if (nombreCliente != null && nombreCliente.isNotEmpty)
          'nombreCliente': nombreCliente,
        if (casoOriginal['creadoPor'] != null)
          'usuarioId': casoOriginal['creadoPor'],
        'guardado': true,
        'fechaGuardado': DateTime.now().toIso8601String(),
      };

      // Subir firma del cliente si existe como base64 en el draft
      final firmaBase64 = draft['firmaClienteAbiertoBase64'] as String?;
      if (firmaBase64 != null) {
        try {
          final bytes = base64Decode(firmaBase64);
          final result = await CameraService.subirFirmaADrive(
            firmaBytes: bytes,
            nombre: 'firma_cliente_${offlineId}_abierto',
          );
          if (result.exitoso && result.url != null) {
            estadoAbierto['firmaClienteUrl'] = result.url;
          }
        } catch (e) {
          debugPrint('⚠️ No se pudo subir firma cliente abierto: $e');
        }
      }

      firestoreData['estadoAbierto'] = estadoAbierto;
    }

    // Estado cerrado (si el inspector cerró el caso offline)
    final descripcionSolucion = draft['descripcionSolucion'] as String?;
    final nombreClienteCerrado = draft['nombreClienteCerrado'] as String?;
    final fotoCerradoUrl = draft['fotoCerradoUrl'] as String?;

    final hayDatosCerrado = (descripcionSolucion != null && descripcionSolucion.isNotEmpty);

    if (hayDatosCerrado) {
      final estadoCerrado = <String, dynamic>{
        'descripcionSolucion': descripcionSolucion,
        if (fotoCerradoUrl != null) 'fotoUrl': fotoCerradoUrl,
        if (nombreClienteCerrado != null && nombreClienteCerrado.isNotEmpty)
          'nombreCliente': nombreClienteCerrado,
        if (casoOriginal['creadoPor'] != null)
          'usuarioId': casoOriginal['creadoPor'],
        'guardado': true,
        'fechaGuardado': DateTime.now().toIso8601String(),
      };

      // Subir firma del cliente cerrado si existe como base64 en el draft
      final firmaCerradoBase64 = draft['firmaClienteCerradoBase64'] as String?;
      if (firmaCerradoBase64 != null) {
        try {
          final bytes = base64Decode(firmaCerradoBase64);
          final result = await CameraService.subirFirmaADrive(
            firmaBytes: bytes,
            nombre: 'firma_cliente_${offlineId}_cerrado',
          );
          if (result.exitoso && result.url != null) {
            estadoCerrado['firmaClienteUrl'] = result.url;
          }
        } catch (e) {
          debugPrint('⚠️ No se pudo subir firma cliente cerrado: $e');
        }
      }

      firestoreData['estadoCerrado'] = estadoCerrado;
      firestoreData['cerrado'] = true;
    }
  }

  /// Migra el draft de offlineId a firestoreId para que case_detail_screen
  /// pueda encontrarlo después del sync.
  Future<void> _migrateDraft(String offlineId, String firestoreId) async {
    try {
      final draft = await CaseDraftService.instance.getDraft(offlineId);
      if (draft != null) {
        await CaseDraftService.instance.saveDraft(firestoreId, draft);
        await CaseDraftService.instance.deleteDraft(offlineId);
        debugPrint('📋 Draft migrado: $offlineId → $firestoreId');
      }
    } catch (e) {
      debugPrint('⚠️ Error migrando draft: $e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _doneController.close();
  }
}

/// Registro interno de un caso sincronizado exitosamente.
class _SyncedEntry {
  final String offlineId;
  final String firestoreId;
  const _SyncedEntry({required this.offlineId, required this.firestoreId});
}