// lib/services/license_cache_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Mantiene un caché local del estado de la suscripción del grupo del usuario.
///
/// Sirve dos propósitos:
///   1. Permitir que el inspector trabaje offline confiando en el último
///      estado conocido de la licencia (sin tener que consultar Firestore).
///   2. Bloquear el uso indefinido de la app sin pagar — si pasan más de
///      7 días sin un refresh exitoso desde Firestore, la app se autobloquea
///      y exige conexión para validar la licencia.
///
/// Estructura en Hive (box: 'license_cache'):
///   {
///     'grupoId':           String,       // a quién pertenece este caché
///     'activo':            bool,         // último estado conocido
///     'fechaVencimiento':  String?,      // ISO8601 — null si nunca pagó
///     'ultimoRefresh':     String,       // ISO8601 — última lectura exitosa
///   }
class LicenseCacheService {
  LicenseCacheService._();
  static final LicenseCacheService instance = LicenseCacheService._();

  static const String _boxName = 'license_cache';
  static const String _key = 'current';

  /// Días que el inspector puede trabajar offline sin refrescar la licencia.
  /// Después de este período, la app se bloquea y exige conexión.
  static const int gracePeriodDias = 7;

  Box<dynamic>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _b {
    assert(_box != null, 'LicenseCacheService.init() no fue llamado');
    return _box!;
  }

  /// Lee el estado actual del caché. Devuelve null si nunca se ha refrescado.
  Map<String, dynamic>? _read() {
    final raw = _b.get(_key);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// Refresca el caché consultando Firestore.
  /// Solo debe llamarse cuando hay conexión.
  /// Si falla (sin red, error de Firestore, etc.), el caché queda intacto.
  Future<bool> refresh(String grupoId) async {
    if (grupoId.isEmpty) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('grupos')
          .doc(grupoId)
          .get();

      if (!doc.exists) {
        debugPrint('⚠️ LicenseCache: grupo $grupoId no existe');
        return false;
      }

      final data = doc.data()!;
      final activo = data['activo'] as bool? ?? true;
      final vencimientoTs = data['fechaVencimiento'] as Timestamp?;
      final vencimientoIso = vencimientoTs?.toDate().toIso8601String();

      await _b.put(_key, {
        'grupoId': grupoId,
        'activo': activo,
        'fechaVencimiento': vencimientoIso,
        'ultimoRefresh': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ LicenseCache: refrescado para $grupoId — activo=$activo');
      return true;
    } catch (e) {
      debugPrint('❌ LicenseCache: error refrescando — $e');
      return false;
    }
  }

  /// Borra el caché. Útil al cerrar sesión.
  Future<void> clear() async {
    await _b.delete(_key);
  }

  /// Verifica localmente (sin tocar Firestore) si el grupo puede operar.
  /// Esta es la función que se llama antes de crear/cerrar/modificar casos.
  LicenseCheckResult puedeOperarLocal(String grupoId) {
    if (grupoId.isEmpty) {
      return const LicenseCheckResult(
        permitido: false,
        razon: LicenseDenialReason.sinCache,
      );
    }

    final cache = _read();

    // Nunca se ha refrescado → exigir primer login online
    if (cache == null) {
      return const LicenseCheckResult(
        permitido: false,
        razon: LicenseDenialReason.sinCache,
      );
    }

    // El caché es de otro grupo (cambio de usuario sin clear) → tratar como sin caché
    final cachedGrupoId = cache['grupoId'] as String?;
    if (cachedGrupoId != grupoId) {
      return const LicenseCheckResult(
        permitido: false,
        razon: LicenseDenialReason.sinCache,
      );
    }

    // Verificar grace period
    final ultimoRefreshIso = cache['ultimoRefresh'] as String?;
    if (ultimoRefreshIso == null) {
      return const LicenseCheckResult(
        permitido: false,
        razon: LicenseDenialReason.sinCache,
      );
    }
    final ultimoRefresh = DateTime.tryParse(ultimoRefreshIso);
    if (ultimoRefresh == null) {
      return const LicenseCheckResult(
        permitido: false,
        razon: LicenseDenialReason.sinCache,
      );
    }
    final diasDesdeRefresh = DateTime.now().difference(ultimoRefresh).inDays;
    if (diasDesdeRefresh > gracePeriodDias) {
      return LicenseCheckResult(
        permitido: false,
        razon: LicenseDenialReason.gracePeriodExcedido,
        diasDesdeRefresh: diasDesdeRefresh,
      );
    }

    // Verificar que el grupo estaba activo en el último refresh
    final activo = cache['activo'] as bool? ?? false;
    if (!activo) {
      return const LicenseCheckResult(
        permitido: false,
        razon: LicenseDenialReason.grupoSuspendido,
      );
    }

    // Verificar fecha de vencimiento cacheada (defensa adicional)
    final vencimientoIso = cache['fechaVencimiento'] as String?;
    if (vencimientoIso != null) {
      final vencimiento = DateTime.tryParse(vencimientoIso);
      if (vencimiento != null && DateTime.now().isAfter(vencimiento)) {
        return const LicenseCheckResult(
          permitido: false,
          razon: LicenseDenialReason.licenciaVencida,
        );
      }
    }

    return const LicenseCheckResult(permitido: true);
  }

  /// Información del último refresh — útil para mostrar al usuario.
  DateTime? get ultimoRefresh {
    final cache = _read();
    final iso = cache?['ultimoRefresh'] as String?;
    return iso != null ? DateTime.tryParse(iso) : null;
  }
}

/// Razones por las que se puede denegar una operación.
enum LicenseDenialReason {
  /// Nunca se ha refrescado el caché — el usuario debe conectarse al menos una vez.
  sinCache,

  /// El grupo está marcado como suspendido en el último refresh conocido.
  grupoSuspendido,

  /// La fecha de vencimiento cacheada ya pasó.
  licenciaVencida,

  /// Pasaron más de N días sin un refresh exitoso desde Firestore.
  gracePeriodExcedido,
}

/// Resultado de un chequeo local de licencia.
class LicenseCheckResult {
  final bool permitido;
  final LicenseDenialReason? razon;
  final int? diasDesdeRefresh;

  const LicenseCheckResult({
    required this.permitido,
    this.razon,
    this.diasDesdeRefresh,
  });

  /// Mensaje listo para mostrar al usuario.
  String get mensajeUsuario {
    switch (razon) {
      case LicenseDenialReason.sinCache:
        return 'Necesitamos validar tu licencia. Por favor conéctate a internet '
            'para continuar usando la app.';
      case LicenseDenialReason.grupoSuspendido:
        return 'La suscripción de tu grupo está suspendida. Contacta al '
            'administrador del grupo para regularizar el pago y reactivar el servicio.';
      case LicenseDenialReason.licenciaVencida:
        return 'La suscripción de tu grupo ha vencido. Contacta al administrador '
            'del grupo para renovar el pago.';
      case LicenseDenialReason.gracePeriodExcedido:
        final dias = diasDesdeRefresh ?? LicenseCacheService.gracePeriodDias;
        return 'Han pasado $dias días desde la última vez que validamos tu licencia. '
            'Por favor conéctate a internet para continuar trabajando.';
      case null:
        return '';
    }
  }

  /// Título corto para el AlertDialog.
  String get titulo {
    switch (razon) {
      case LicenseDenialReason.sinCache:
        return 'Validación requerida';
      case LicenseDenialReason.grupoSuspendido:
        return 'Suscripción suspendida';
      case LicenseDenialReason.licenciaVencida:
        return 'Suscripción vencida';
      case LicenseDenialReason.gracePeriodExcedido:
        return 'Conexión requerida';
      case null:
        return '';
    }
  }
}
