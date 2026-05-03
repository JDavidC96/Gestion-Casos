// lib/controllers/case_detail_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firebase_service.dart';
import '../services/camera_service.dart';
import '../services/case_draft_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_case_service.dart';

class CaseDetailController with ChangeNotifier {

  String? grupoId;
  String? empresaId;
  String? centroId;
  String? casoId;

  Map<String, dynamic>? casoData;
  bool isLoading = false;
  bool casoCerrado = false;

  String descripcionHallazgo = '';
  String nivelPeligro = 'Medio';
  String? tipoPeligroLibre;   // Modo texto libre — alternativa al catálogo de peligros
  String? recomendacionesControl;
  String? fotoAbiertoPath;
  String? fotoAbiertoUrl;
  Uint8List? firmaAbierto;
  String? firmaAbiertoUrl;
  Position? ubicacionAbierto;
  bool estadoAbiertoGuardado = false;
  String? responsableAbiertoNombre;
  final TextEditingController ubicacionTextoCtrl = TextEditingController();
  Uint8List? firmaClienteAbierto;
  String? firmaClienteAbiertoUrl;
  String? nombreClienteAbierto;

  String descripcionSolucion = '';
  String? fotoCerradoPath;
  String? fotoCerradoUrl;
  Uint8List? firmaCerrado;
  String? firmaCerradoUrl;
  Position? ubicacionCerrado;
  bool estadoCerradoGuardado = false;
  String? responsableCerradoNombre;
  Uint8List? firmaClienteCerrado;
  String? firmaClienteCerradoUrl;
  String? nombreClienteCerrado;

  String? usuarioId;
  String? usuarioNombre;

  bool tomandoFoto = false;
  bool subiendoFotoAbierto = false;
  bool subiendoFotoCerrado = false;

  Timer? _draftDebounce;
  bool _draftRestored = false;

  void initFromArgs(Map? args) {
    if (args == null) return;
    grupoId   = args['grupoId']   as String?;
    empresaId = args['empresaId'] as String?;
    centroId  = args['centroId']  as String?;
    casoId    = args['casoId']    as String?;
  }

  void setUsuario(Map<String, dynamic>? userData) {
    if (userData == null) return;
    usuarioId = userData['uid'] as String?;
    usuarioNombre = userData['displayName'] as String? ?? 'Usuario';
    responsableAbiertoNombre = usuarioNombre;
    responsableCerradoNombre = usuarioNombre;
  }

  Future<void> loadFromFirestore() async {
    if (casoId == null) return;
    final doc = await FirebaseService.getCasoById(
        grupoId ?? '', empresaId ?? '', centroId ?? '', casoId!);
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    casoData = data;
    casoCerrado = data['cerrado'] ?? false;
    _loadEstadoAbierto(data);
    _loadEstadoCerrado(data);

    // Restaurar borrador ANTES del primer notifyListeners
    // para que los widgets reciban valores correctos en initState
    _restoreDraftIfAny();

    notifyListeners(); // ← UI se actualiza con datos de Firestore + draft

    // Firmas desde Drive — en segundo plano, no bloquean la UI
    cargarFirmasDesdeDrive(); // sin await
  }

  void _loadEstadoAbierto(Map<String, dynamic> data) {
    final ea = data['estadoAbierto'] as Map<String, dynamic>?;
    if (ea == null) return;
    descripcionHallazgo       = ea['descripcionHallazgo'] ?? '';
    nivelPeligro              = ea['nivelPeligro'] ?? nivelPeligro;
    recomendacionesControl    = ea['recomendacionesControl'];
    fotoAbiertoUrl            = ea['fotoUrl'];
    estadoAbiertoGuardado     = ea['guardado'] ?? false;
    responsableAbiertoNombre  = ea['usuarioNombre'] ?? usuarioNombre;
    ubicacionTextoCtrl.text   = ea['ubicacionTexto'] ?? '';
    nombreClienteAbierto      = ea['nombreCliente'];
    firmaClienteAbiertoUrl    = ea['firmaClienteUrl'] as String?;
    if (ea['firmaUrl'] != null) firmaAbiertoUrl = ea['firmaUrl'] as String?;
    if (ea['ubicacion'] != null) {
      final ub = ea['ubicacion'];
      ubicacionAbierto = Position(
        latitude: ub['latitude'], longitude: ub['longitude'],
        timestamp: DateTime.now(), accuracy: 0, altitude: 0,
        heading: 0, speed: 0, speedAccuracy: 0,
        altitudeAccuracy: 0, headingAccuracy: 0,
      );
    }
  }

  void _loadEstadoCerrado(Map<String, dynamic> data) {
    final ec = data['estadoCerrado'] as Map<String, dynamic>?;
    if (ec == null) return;
    descripcionSolucion      = ec['descripcionSolucion'] ?? '';
    fotoCerradoUrl           = ec['fotoUrl'];
    estadoCerradoGuardado    = ec['guardado'] ?? false;
    responsableCerradoNombre = ec['usuarioNombre'] ?? usuarioNombre;
    nombreClienteCerrado     = ec['nombreCliente'];
    firmaClienteCerradoUrl   = ec['firmaClienteUrl'] as String?;
    if (ec['firmaUrl'] != null) firmaCerradoUrl = ec['firmaUrl'] as String?;
    if (ec['ubicacion'] != null) {
      final ub = ec['ubicacion'];
      ubicacionCerrado = Position(
        latitude: ub['latitude'], longitude: ub['longitude'],
        timestamp: DateTime.now(), accuracy: 0, altitude: 0,
        heading: 0, speed: 0, speedAccuracy: 0,
        altitudeAccuracy: 0, headingAccuracy: 0,
      );
    }
  }

  Future<void> loadFirmaInspectorFromProfile(Map<String, dynamic>? userData) async {
    if (userData == null) return;
    final firmaUrl = userData['firmaUrl'] as String?;
    if (firmaUrl == null) return;
    // Solo usar la firma del perfil si el caso no tiene ya una firma específica
    // cargada desde Firestore — evita sobreescribir la firma guardada del caso.
    if (firmaAbiertoUrl == null) firmaAbiertoUrl = firmaUrl;
    if (firmaCerradoUrl == null) firmaCerradoUrl = firmaUrl;
    // Solo descargar bytes si todavía no se tienen
    if (firmaAbierto == null || firmaCerrado == null) {
      final bytes = await _descargarDesdeDrive(firmaUrl);
      if (bytes != null) {
        if (firmaAbierto == null) firmaAbierto = bytes;
        if (firmaCerrado == null) firmaCerrado = bytes;
        notifyListeners();
      }
    }
  }

  Future<void> cargarFirmasDesdeDrive() async {
    bool changed = false;
    if (firmaAbiertoUrl != null && firmaAbierto == null) {
      final b = await _descargarDesdeDrive(firmaAbiertoUrl);
      if (b != null) { firmaAbierto = b; changed = true; }
    }
    if (firmaCerradoUrl != null && firmaCerrado == null) {
      final b = await _descargarDesdeDrive(firmaCerradoUrl);
      if (b != null) { firmaCerrado = b; changed = true; }
    }
    if (firmaClienteAbiertoUrl != null && firmaClienteAbierto == null) {
      final b = await _descargarDesdeDrive(firmaClienteAbiertoUrl);
      if (b != null) { firmaClienteAbierto = b; changed = true; }
    }
    if (firmaClienteCerradoUrl != null && firmaClienteCerrado == null) {
      final b = await _descargarDesdeDrive(firmaClienteCerradoUrl);
      if (b != null) { firmaClienteCerrado = b; changed = true; }
    }
    if (changed) notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  FIRMA DEL CLIENTE — persistencia vía draft (base64)
  // ═══════════════════════════════════════════════════════════════════

  /// Asigna los bytes de la firma del cliente y guarda el draft inmediatamente.
  /// Los bytes se persisten como base64 en el draft de Hive — no depende de
  /// async file I/O, así que no se pierde si el usuario sale rápido.
  void setFirmaCliente({
    required bool esAbierto,
    required Uint8List? bytes,
  }) {
    if (esAbierto) {
      firmaClienteAbierto = bytes;
    } else {
      firmaClienteCerrado = bytes;
    }
    // Guardar inmediatamente — el base64 va directo al draft
    _saveDraftNow();
    notifyListeners();
  }

  static String? _convertirUrlDrive(String? url) {
    if (url == null) return null;
    if (url.contains('drive.google.com')) {
      final fileId = RegExp(r'\/d\/([a-zA-Z0-9-_]+)').firstMatch(url)?.group(1);
      if (fileId != null) return 'https://drive.google.com/uc?export=download&id=$fileId';
    }
    return url;
  }

  Future<Uint8List?> _descargarDesdeDrive(String? driveUrl) async {
    final directUrl = _convertirUrlDrive(driveUrl);
    if (directUrl == null) return null;
    try {
      final response = await http.get(Uri.parse(directUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  FOTO — con limpieza automática si falla la subida
  // ═══════════════════════════════════════════════════════════════════

  /// Retorna null si fue exitoso, o un mensaje de error si falló.
  /// Si la subida a Drive falla, elimina la foto local y limpia el estado.
  Future<String?> tomarFoto({required bool esEstadoAbierto}) async {
    if (tomandoFoto) return null;
    if ((esEstadoAbierto && estadoAbiertoGuardado) ||
        (!esEstadoAbierto && estadoCerradoGuardado)) {
      return null;
    }

    tomandoFoto = true;
    notifyListeners();

    try {
      final captura = await CameraService.tomarFoto();
      if (captura == null) return null; // usuario canceló

      tomandoFoto = false;
      if (esEstadoAbierto) {
        fotoAbiertoPath = captura.fotoPath;
        fotoAbiertoUrl = null;
        ubicacionAbierto = captura.ubicacion;
        subiendoFotoAbierto = true;
      } else {
        fotoCerradoPath = captura.fotoPath;
        fotoCerradoUrl = null;
        ubicacionCerrado = captura.ubicacion;
        subiendoFotoCerrado = true;
      }
      notifyListeners();

      // Si no hay red, guardar solo la ruta local (se subirá al sincronizar)
      if (!ConnectivityService.instance.isOnline) {
        scheduleDraftSave();
        // Guardar ruta local en el caso offline si corresponde
        if (casoId != null && casoId!.startsWith('offline_')) {
          await OfflineCaseService.instance.addLocalPhoto(
            casoId!, captura.fotoPath, esAbierto: esEstadoAbierto);
        }
        return null; // ✅ foto guardada localmente
      }

      // Upload a Drive
      final subida = await CameraService.subirFotoADrive(captura.xFile);

      if (subida.exitoso && subida.url != null) {
        // ✅ Éxito — guardar URL
        if (esEstadoAbierto) {
          fotoAbiertoUrl = subida.url;
        } else {
          fotoCerradoUrl = subida.url;
        }
        scheduleDraftSave();
        return null;
      } else {
        // ❌ Fallo — limpiar foto local y resetear estado
        await CameraService.eliminarFotoLocal(captura.fotoPath);
        if (esEstadoAbierto) {
          fotoAbiertoPath = null;
          fotoAbiertoUrl = null;
          ubicacionAbierto = null;
        } else {
          fotoCerradoPath = null;
          fotoCerradoUrl = null;
          ubicacionCerrado = null;
        }
        return subida.mensaje;
      }
    } catch (e) {
      return 'Error al tomar foto: $e';
    } finally {
      tomandoFoto = false;
      subiendoFotoAbierto = false;
      subiendoFotoCerrado = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  GUARDAR ESTADOS
  // ═══════════════════════════════════════════════════════════════════

  Future<String?> guardarEstadoAbierto({required bool mostrarNivelPeligro, required bool habilitarFotos}) async {
    if (casoId == null) return 'ID de caso no disponible';
    if (descripcionHallazgo.trim().isEmpty) return 'La descripción del hallazgo es requerida';
    if (mostrarNivelPeligro && nivelPeligro.isEmpty) return 'Selecciona un Nivel de peligro válido';

    final tieneFoto = fotoAbiertoUrl != null || fotoAbiertoPath != null;
    if (habilitarFotos && !estadoAbiertoGuardado && !tieneFoto) return 'Agrega una foto del hallazgo';

    isLoading = true;
    notifyListeners();

    try {
      String? firmaClienteUrl;
      if (firmaClienteAbierto != null) {
        final firmaResult = await CameraService.subirFirmaADrive(
          firmaBytes: firmaClienteAbierto!, nombre: 'firma_cliente_${casoId}_abierto',
        );
        if (firmaResult.exitoso) firmaClienteUrl = firmaResult.url;
      }

      final estadoAbiertoData = {
        'descripcionHallazgo': descripcionHallazgo.trim(),
        'recomendacionesControl': recomendacionesControl?.trim(),
        'fotoUrl': fotoAbiertoUrl,
        'usuarioId': usuarioId,
        'usuarioNombre': usuarioNombre,
        'ubicacionTexto': ubicacionTextoCtrl.text.trim(),
        'ubicacion': ubicacionAbierto != null
            ? {'latitude': ubicacionAbierto!.latitude, 'longitude': ubicacionAbierto!.longitude}
            : null,
        'guardado': true,
        'fechaGuardado': FieldValue.serverTimestamp(),
        if (firmaClienteUrl != null) 'firmaClienteUrl': firmaClienteUrl,
        if (nombreClienteAbierto != null && nombreClienteAbierto!.isNotEmpty)
          'nombreCliente': nombreClienteAbierto,
      };
      if (mostrarNivelPeligro) estadoAbiertoData['nivelPeligro'] = nivelPeligro;
      if (tipoPeligroLibre != null && tipoPeligroLibre!.trim().isNotEmpty)
        estadoAbiertoData['tipoPeligroLibre'] = tipoPeligroLibre!.trim();

      await FirebaseService.updateEstadoAbierto(
          grupoId ?? '', empresaId ?? '', centroId ?? '', casoId!, estadoAbiertoData);

      estadoAbiertoGuardado = true;
      responsableAbiertoNombre = usuarioNombre;

      // Actualizar URL de firma del cliente y reflejar en casoData
      // para que ReportScreen reciba los datos correctos sin recargar.
      if (firmaClienteUrl != null) {
        firmaClienteAbiertoUrl = firmaClienteUrl;
      }
      final eaActual = Map<String, dynamic>.from(
          (casoData?['estadoAbierto'] as Map<String, dynamic>?) ?? {});
      eaActual['firmaClienteUrl'] = firmaClienteAbiertoUrl;
      eaActual['fotoUrl']         = fotoAbiertoUrl;
      eaActual['guardado']        = true;
      casoData = {...?casoData, 'estadoAbierto': eaActual};

      return null;
    } catch (e) {
      return 'Error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> guardarEstadoCerrado({required bool habilitarFotos}) async {
    if (casoId == null) return 'ID de caso no disponible';
    if (descripcionSolucion.trim().isEmpty) return 'La descripción de la solución es requerida';

    final tieneFoto = fotoCerradoUrl != null || fotoCerradoPath != null;
    if (habilitarFotos && !estadoCerradoGuardado && !tieneFoto) return 'Agrega una foto de la solución';

    isLoading = true;
    notifyListeners();

    try {
      String? firmaClienteUrl;
      if (firmaClienteCerrado != null) {
        final firmaResult = await CameraService.subirFirmaADrive(
          firmaBytes: firmaClienteCerrado!, nombre: 'firma_cliente_${casoId}_cerrado',
        );
        if (firmaResult.exitoso) firmaClienteUrl = firmaResult.url;
      }

      final estadoCerradoData = {
        'descripcionSolucion': descripcionSolucion.trim(),
        'fotoUrl': fotoCerradoUrl,
        'usuarioId': usuarioId,
        'usuarioNombre': usuarioNombre,
        'ubicacion': ubicacionCerrado != null
            ? {'latitude': ubicacionCerrado!.latitude, 'longitude': ubicacionCerrado!.longitude}
            : null,
        'guardado': true,
        'fechaGuardado': FieldValue.serverTimestamp(),
        if (firmaClienteUrl != null) 'firmaClienteUrl': firmaClienteUrl,
        if (nombreClienteCerrado != null && nombreClienteCerrado!.isNotEmpty)
          'nombreCliente': nombreClienteCerrado,
      };

      await FirebaseService.updateEstadoCerrado(
          grupoId ?? '', empresaId ?? '', centroId ?? '', casoId!, estadoCerradoData);

      estadoCerradoGuardado = true;
      casoCerrado = true;
      responsableCerradoNombre = usuarioNombre;

      // Actualizar URL de firma del cliente y reflejar en casoData
      if (firmaClienteUrl != null) {
        firmaClienteCerradoUrl = firmaClienteUrl;
      }
      final ecActual = Map<String, dynamic>.from(
          (casoData?['estadoCerrado'] as Map<String, dynamic>?) ?? {});
      ecActual['firmaClienteUrl'] = firmaClienteCerradoUrl;
      ecActual['fotoUrl']         = fotoCerradoUrl;
      ecActual['guardado']        = true;
      casoData = {...?casoData, 'estadoCerrado': ecActual};

      return null;
    } catch (e) {
      return 'Error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BORRADORES
  // ═══════════════════════════════════════════════════════════════════

  Map<String, dynamic> _buildDraft() => {
    'descripcionHallazgo': descripcionHallazgo,
    'nivelPeligro': nivelPeligro,
    'tipoPeligroLibre': tipoPeligroLibre,
    'recomendacionesControl': recomendacionesControl,
    'fotoAbiertoPath': fotoAbiertoPath,
    'fotoAbiertoUrl': fotoAbiertoUrl,
    'descripcionSolucion': descripcionSolucion,
    'fotoCerradoPath': fotoCerradoPath,
    'ubicacionTexto': ubicacionTextoCtrl.text,
    'fotoCerradoUrl': fotoCerradoUrl,
    'nombreClienteAbierto': nombreClienteAbierto,
    'nombreClienteCerrado': nombreClienteCerrado,
    // Firma bytes como base64 — source of truth, síncrono, no depende de I/O
    'firmaClienteAbiertoBase64': firmaClienteAbierto != null
        ? base64Encode(firmaClienteAbierto!) : null,
    'firmaClienteCerradoBase64': firmaClienteCerrado != null
        ? base64Encode(firmaClienteCerrado!) : null,
  };

  void scheduleDraftSave() {
    if (casoId == null) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 600), () async {
      try { await CaseDraftService.instance.saveDraft(casoId!, _buildDraft()); } catch (_) {}
    });
  }

  /// Guarda el draft SIN debounce — para datos críticos como firmas
  /// y para el flush final en dispose().
  void _saveDraftNow() {
    if (casoId == null) return;
    _draftDebounce?.cancel();
    try {
      CaseDraftService.instance.saveDraft(casoId!, _buildDraft());
    } catch (_) {}
  }

  /// Restaura el borrador de forma SÍNCRONA para que los valores estén
  /// disponibles antes del primer notifyListeners() → el widget recibe
  /// los datos correctos desde su initState.
  void _restoreDraftIfAny() {
    if (casoId == null || _draftRestored) return;
    final draft = CaseDraftService.instance.getDraftSync(casoId!);
    _draftRestored = true;
    if (draft == null) return;
    if (!estadoAbiertoGuardado) {
      descripcionHallazgo    = draft['descripcionHallazgo'] ?? descripcionHallazgo;
      nivelPeligro           = draft['nivelPeligro'] ?? nivelPeligro;
      tipoPeligroLibre       = draft['tipoPeligroLibre'] ?? tipoPeligroLibre;
      final ut = draft['ubicacionTexto'];
      if (ut != null && ubicacionTextoCtrl.text.isEmpty) ubicacionTextoCtrl.text = ut;
      recomendacionesControl = draft['recomendacionesControl'] ?? recomendacionesControl;
      if (fotoAbiertoUrl == null) {
        fotoAbiertoPath = draft['fotoAbiertoPath'] ?? fotoAbiertoPath;
        fotoAbiertoUrl  = draft['fotoAbiertoUrl']  ?? fotoAbiertoUrl;
      }
      nombreClienteAbierto = draft['nombreClienteAbierto'] ?? nombreClienteAbierto;
      // Restaurar firma del cliente desde base64 en el draft
      final firmaAbBase64 = draft['firmaClienteAbiertoBase64'] as String?;
      if (firmaAbBase64 != null && firmaClienteAbierto == null) {
        try {
          firmaClienteAbierto = base64Decode(firmaAbBase64);
        } catch (_) {}
      }
    }
    if (!estadoCerradoGuardado) {
      descripcionSolucion = draft['descripcionSolucion'] ?? descripcionSolucion;
      if (fotoCerradoUrl == null) {
        fotoCerradoPath = draft['fotoCerradoPath'] ?? fotoCerradoPath;
        fotoCerradoUrl  = draft['fotoCerradoUrl']  ?? fotoCerradoUrl;
      }
      nombreClienteCerrado = draft['nombreClienteCerrado'] ?? nombreClienteCerrado;
      // Restaurar firma del cliente desde base64 en el draft
      final firmaCeBase64 = draft['firmaClienteCerradoBase64'] as String?;
      if (firmaCeBase64 != null && firmaClienteCerrado == null) {
        try {
          firmaClienteCerrado = base64Decode(firmaCeBase64);
        } catch (_) {}
      }
    }
    // NO llamar notifyListeners() aquí — el llamador lo hace después
  }

  /// Carga los datos de un caso offline desde Hive (sin Firestore).
  /// Se llama en lugar de loadFromFirestore() cuando el caso tiene
  /// un ID temporal "offline_xxx".
  void loadFromLocalData(Map<String, dynamic> data) {
    casoData = data;

    final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>?;
    if (estadoAbierto != null) {
      descripcionHallazgo     = estadoAbierto['descripcionHallazgo'] as String? ?? '';
      nivelPeligro            = estadoAbierto['nivelPeligro'] as String? ?? '';
      tipoPeligroLibre        = estadoAbierto['tipoPeligroLibre'] as String?;
      recomendacionesControl  = estadoAbierto['recomendacionesControl'] as String?;
      fotoAbiertoUrl          = estadoAbierto['fotoUrl'] as String?;
      nombreClienteAbierto    = estadoAbierto['nombreClienteAbierto'] as String?;
      ubicacionTextoCtrl.text = estadoAbierto['ubicacionTexto'] as String? ?? '';
    } else {
      nivelPeligro = data['nivelPeligro'] as String? ?? '';
    }

    fotoAbiertoPath = data['fotoLocalAbierto'] as String?;

    estadoAbiertoGuardado = false;
    estadoCerradoGuardado = false;
    casoCerrado           = false;

    // Restaurar borrador ANTES del primer notifyListeners
    // para que los widgets reciban valores correctos en initState
    _restoreDraftIfAny();

    notifyListeners();
  }

  /// Llamar cuando el SyncService sincroniza este caso offline.
  /// Actualiza el casoId al ID real de Firestore sin recargar los datos
  /// del formulario — preserva lo que el usuario ya escribió.
  void onCaseSynced(String firestoreId) {
    casoId = firestoreId;
    notifyListeners();
  }

  @override
  void dispose() {
    // ── Guardar draft INMEDIATAMENTE antes de destruir la pantalla ──
    // El debounce de 600ms podría estar pendiente con datos no guardados
    // (ej. el nombre del cliente o la ruta de la firma).
    _saveDraftNow();
    ubicacionTextoCtrl.dispose();
    super.dispose();
  }
}