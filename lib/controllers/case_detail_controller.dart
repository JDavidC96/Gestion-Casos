// lib/controllers/case_detail_controller.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firebase_service.dart';
import '../services/camera_service.dart';
import '../services/case_draft_service.dart';

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
    notifyListeners();
    await _restoreDraftIfAny();
    await cargarFirmasDesdeDrive();
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
    firmaAbiertoUrl = firmaUrl;
    firmaCerradoUrl = firmaUrl;
    final bytes = await _descargarDesdeDrive(firmaUrl);
    if (bytes != null) {
      firmaAbierto = bytes;
      firmaCerrado = bytes;
      notifyListeners();
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
        (!esEstadoAbierto && estadoCerradoGuardado)) return null;

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

      await FirebaseService.updateEstadoAbierto(
          grupoId ?? '', empresaId ?? '', centroId ?? '', casoId!, estadoAbiertoData);

      estadoAbiertoGuardado = true;
      responsableAbiertoNombre = usuarioNombre;
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
    'recomendacionesControl': recomendacionesControl,
    'fotoAbiertoPath': fotoAbiertoPath,
    'fotoAbiertoUrl': fotoAbiertoUrl,
    'descripcionSolucion': descripcionSolucion,
    'fotoCerradoPath': fotoCerradoPath,
    'ubicacionTexto': ubicacionTextoCtrl.text,
    'fotoCerradoUrl': fotoCerradoUrl,
    'nombreClienteAbierto': nombreClienteAbierto,
    'nombreClienteCerrado': nombreClienteCerrado,
  };

  void scheduleDraftSave() {
    if (casoId == null) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 600), () async {
      try { await CaseDraftService.instance.saveDraft(casoId!, _buildDraft()); } catch (_) {}
    });
  }

  Future<void> _restoreDraftIfAny() async {
    if (casoId == null || _draftRestored) return;
    final draft = await CaseDraftService.instance.getDraft(casoId!);
    _draftRestored = true;
    if (draft == null) return;
    if (!estadoAbiertoGuardado) {
      descripcionHallazgo    = draft['descripcionHallazgo'] ?? descripcionHallazgo;
      nivelPeligro           = draft['nivelPeligro'] ?? nivelPeligro;
      final ut = draft['ubicacionTexto'];
      if (ut != null && ubicacionTextoCtrl.text.isEmpty) ubicacionTextoCtrl.text = ut;
      recomendacionesControl = draft['recomendacionesControl'] ?? recomendacionesControl;
      if (fotoAbiertoUrl == null) {
        fotoAbiertoPath = draft['fotoAbiertoPath'] ?? fotoAbiertoPath;
        fotoAbiertoUrl  = draft['fotoAbiertoUrl']  ?? fotoAbiertoUrl;
      }
      nombreClienteAbierto = draft['nombreClienteAbierto'] ?? nombreClienteAbierto;
    }
    if (!estadoCerradoGuardado) {
      descripcionSolucion = draft['descripcionSolucion'] ?? descripcionSolucion;
      if (fotoCerradoUrl == null) {
        fotoCerradoPath = draft['fotoCerradoPath'] ?? fotoCerradoPath;
        fotoCerradoUrl  = draft['fotoCerradoUrl']  ?? fotoCerradoUrl;
      }
      nombreClienteCerrado = draft['nombreClienteCerrado'] ?? nombreClienteCerrado;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    ubicacionTextoCtrl.dispose();
    _draftDebounce?.cancel();
    super.dispose();
  }
}