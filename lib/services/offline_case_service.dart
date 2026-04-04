// lib/services/offline_case_service.dart
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

/// Servicio que gestiona casos creados sin conexión.
///
/// Estructura de cada caso offline en Hive:
/// {
///   'offlineId':        'offline_1234567890',   // clave en el box
///   'nombre':           String,
///   'tipoRiesgo':       String,
///   'subgrupoRiesgo':   String,
///   'nivelPeligro':     String?,
///   'cerrado':          false,
///   'centroId':         String,
///   'centroNombre':     String?,
///   'empresaId':        String,
///   'empresaNombre':    String,
///   'grupoId':          String,
///   'grupoNombre':      String?,
///   'numeroCategoria':  int,
///   'creadoPor':        String?,
///   'creadoAt':         String (ISO8601),
///   'sincronizado':     false,
///   'fotosLocales':     List<String>,   // rutas locales pendientes de subir
/// }

class OfflineCaseService {
  OfflineCaseService._();
  static final OfflineCaseService instance = OfflineCaseService._();

  static const _boxName = 'casos_offline';
  Box<dynamic>? _box;

  // Stream que emite la lista actualizada cada vez que cambia
  final _controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get casesStream => _controller.stream;

  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _b {
    assert(_box != null, 'OfflineCaseService.init() no fue llamado');
    return _box!;
  }

  // ── Lectura ──────────────────────────────────────────────────────────────

  /// Todos los casos offline (sincronizados o no).
  /// Solo lee claves que NO son entradas de caché Firestore.
  List<Map<String, dynamic>> getAll() {
    final result = <Map<String, dynamic>>[];
    for (final key in _b.keys) {
      if (key is String && key.startsWith(_cachePrefix)) continue;
      final val = _b.get(key);
      if (val is Map) {
        result.add(Map<String, dynamic>.from(val));
      }
    }
    return result;
  }

  /// Solo los casos que aún no se han sincronizado con Firestore.
  List<Map<String, dynamic>> getPending() {
    return getAll().where((c) => c['sincronizado'] != true).toList();
  }

  /// Un caso por su offlineId.
  Map<String, dynamic>? getCase(String offlineId) {
    final raw = _b.get(offlineId);
    if (raw == null) return null;
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  // ── Escritura ────────────────────────────────────────────────────────────

  /// Guarda un nuevo caso offline. Genera el offlineId automáticamente.
  /// Devuelve el offlineId asignado.
  Future<String> saveCase(Map<String, dynamic> data) async {
    final offlineId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    final entry = {
      ...data,
      'offlineId': offlineId,
      'sincronizado': false,
      'creadoAt': DateTime.now().toIso8601String(),
      'fotosLocales': data['fotosLocales'] ?? <String>[],
    };
    await _b.put(offlineId, entry);
    _notify();
    return offlineId;
  }

  /// Agrega una ruta de foto local a un caso offline existente.
  Future<void> addLocalPhoto(String offlineId, String photoPath,
      {required bool esAbierto}) async {
    final existing = getCase(offlineId);
    if (existing == null) return;

    final key = esAbierto ? 'fotoLocalAbierto' : 'fotoLocalCerrado';
    existing[key] = photoPath;
    await _b.put(offlineId, existing);
    _notify();
  }

  /// Actualiza campos de un caso offline (descripción, nivel, etc.).
  Future<void> updateCase(
      String offlineId, Map<String, dynamic> updates) async {
    final existing = getCase(offlineId);
    if (existing == null) return;
    existing.addAll(updates);
    await _b.put(offlineId, existing);
    _notify();
  }

  /// Marca un caso como sincronizado y opcionalmente actualiza su ID real.
  Future<void> markSynced(String offlineId, {String? firestoreId}) async {
    final existing = getCase(offlineId);
    if (existing == null) return;
    existing['sincronizado'] = true;
    if (firestoreId != null) existing['firestoreId'] = firestoreId;
    await _b.put(offlineId, existing);
    _notify();
  }

  /// Elimina un caso offline (tras sincronizar o si el usuario lo descarta).
  Future<void> deleteCase(String offlineId) async {
    await _b.delete(offlineId);
    _notify();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _notify() {
    _controller.add(getPending());
  }

  void dispose() {
    _controller.close();
  }

  // ── Caché de casos Firestore ─────────────────────────────────────────────
  // Permite mostrar casos ya descargados cuando no hay red.

  static const _cachePrefix = 'firestore_cache_';

  /// Convierte tipos no serializables por Hive (Timestamp → String ISO).
  static dynamic _sanitize(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitize(v)));
    }
    if (value is List) {
      return value.map(_sanitize).toList();
    }
    // Firestore Timestamp → ISO8601 String
    // Usamos runtimeType string para no importar cloud_firestore aquí
    final typeName = value.runtimeType.toString();
    if (typeName == 'Timestamp') {
      try {
        // Timestamp tiene .toDate() → DateTime
        final dt = (value as dynamic).toDate() as DateTime;
        return dt.toIso8601String();
      } catch (_) {
        return value.toString();
      }
    }
    return value;
  }

  /// Guarda una lista de casos de Firestore en caché local.
  /// Sanitiza Timestamps para que Hive pueda serializarlos.
  Future<void> saveFirestoreCache(
      String cacheKey, List<Map<String, dynamic>> casos) async {
    try {
      final sanitized = casos.map((c) {
        final s = _sanitize(c);
        return s is Map ? Map<String, dynamic>.from(s.map((k, v) => MapEntry(k.toString(), v))) : <String, dynamic>{};
      }).toList();
      await _b.put('$_cachePrefix$cacheKey', sanitized);
    } catch (_) {
      // Si falla la escritura del caché no es crítico — ignorar
    }
  }

  /// Lee la caché de casos Firestore. Devuelve lista vacía si no hay caché.
  List<Map<String, dynamic>> getFirestoreCache(String cacheKey) {
    final raw = _b.get('$_cachePrefix$cacheKey');
    if (raw == null) return [];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => _deepCast(e))
        .toList();
  }

  /// Convierte recursivamente un Map<dynamic,dynamic> a Map<String,dynamic>.
  static Map<String, dynamic> _deepCast(Map m) {
    return m.map((k, v) {
      final key = k.toString();
      dynamic val;
      if (v is Map) {
        val = _deepCast(v);
      } else if (v is List) {
        val = v.map((item) => item is Map ? _deepCast(item) : item).toList();
      } else {
        val = v;
      }
      return MapEntry(key, val);
    });
  }
}