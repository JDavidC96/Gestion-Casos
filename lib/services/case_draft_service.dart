import 'package:hive/hive.dart';

class CaseDraftService {
  CaseDraftService._();
  static final CaseDraftService instance = CaseDraftService._();

  static const String _boxName = 'case_drafts';
  Box<dynamic>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Future<Map<String, dynamic>?> getDraft(String casoId) async {
    final box = _box ?? await Hive.openBox<dynamic>(_boxName);
    final data = box.get(_key(casoId));
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Versión síncrona — solo funciona si init() ya fue llamado.
  /// Usada por el controller para restaurar borradores antes del primer render.
  Map<String, dynamic>? getDraftSync(String casoId) {
    if (_box == null) return null;
    final data = _box!.get(_key(casoId));
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Future<void> saveDraft(String casoId, Map<String, dynamic> draft) async {
    final box = _box ?? await Hive.openBox<dynamic>(_boxName);
    await box.put(_key(casoId), draft);
  }

  Future<void> deleteDraft(String casoId) async {
    final box = _box ?? await Hive.openBox<dynamic>(_boxName);
    await box.delete(_key(casoId));
  }

  Future<void> removeFields(String casoId, List<String> fields) async {
    final box = _box ?? await Hive.openBox<dynamic>(_boxName);
    final current = await getDraft(casoId);
    if (current == null) return;

    for (final f in fields) {
      current.remove(f);
    }
    await box.put(_key(casoId), current);
  }

  String _key(String casoId) => 'draft_$casoId';
}