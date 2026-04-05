// lib/services/subscription_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Gestiona el estado de suscripción de los grupos.
///
/// Campos en Firestore (grupos/{grupoId}):
///   activo:              bool   — si el grupo puede operar (crear casos, etc.)
///   fechaPago:           Timestamp — última fecha de pago registrada
///   fechaVencimiento:    Timestamp — hasta cuándo está vigente el pago
///   valorMensual:        int    — valor en COP (default 75000)
///   historialPagos:      List   — registro de cada pago [{fecha, monto, nota}]
///   suspendido:          bool   — true si fue suspendido por mora
///   fechaSuspension:     Timestamp? — cuándo se suspendió
///
/// El campo 'activo' que ya existe se reutiliza como el switch principal.
/// Cuando vence y no se renueva → activo = false, suspendido = true.
/// Cuando el SuperAdmin registra pago → activo = true, suspendido = false.
class SubscriptionService {
  static final _db = FirebaseFirestore.instance;

  /// Registra un pago para un grupo.
  /// Activa el grupo y extiende la fecha de vencimiento 30 días desde hoy.
  static Future<void> registrarPago({
    required String grupoId,
    int monto = 75000,
    String? nota,
  }) async {
    final ahora = DateTime.now();
    final vencimiento = ahora.add(const Duration(days: 30));

    final pagoEntry = {
      'fecha': Timestamp.fromDate(ahora),
      'monto': monto,
      'nota': nota ?? 'Pago mensual',
    };

    await _db.collection('grupos').doc(grupoId).update({
      'activo': true,
      'suspendido': false,
      'fechaPago': Timestamp.fromDate(ahora),
      'fechaVencimiento': Timestamp.fromDate(vencimiento),
      'valorMensual': monto,
      'fechaSuspension': null,
      'historialPagos': FieldValue.arrayUnion([pagoEntry]),
    });
  }

  /// Suspende un grupo manualmente (por mora u otra razón).
  /// El grupo queda en modo lectura — puede ver datos pero no crear.
  static Future<void> suspenderGrupo(String grupoId, {String? motivo}) async {
    await _db.collection('grupos').doc(grupoId).update({
      'activo': false,
      'suspendido': true,
      'fechaSuspension': FieldValue.serverTimestamp(),
      'motivoSuspension': motivo ?? 'Pago vencido',
    });
  }

  /// Reactiva un grupo manualmente sin registrar pago.
  static Future<void> reactivarGrupo(String grupoId) async {
    await _db.collection('grupos').doc(grupoId).update({
      'activo': true,
      'suspendido': false,
      'fechaSuspension': null,
      'motivoSuspension': null,
    });
  }

  /// Verifica todos los grupos y suspende los que tienen pago vencido.
  /// Llamar periódicamente (ej. al abrir el dashboard del SuperAdmin).
  static Future<int> verificarVencimientos() async {
    final ahora = DateTime.now();
    final gruposSnap = await _db.collection('grupos').get();
    int suspendidos = 0;

    for (final doc in gruposSnap.docs) {
      final data = doc.data();
      final activo = data['activo'] as bool? ?? true;
      final vencimiento = (data['fechaVencimiento'] as Timestamp?)?.toDate();

      // Solo suspender si está activo Y tiene fecha de vencimiento Y ya venció
      if (activo && vencimiento != null && ahora.isAfter(vencimiento)) {
        await suspenderGrupo(doc.id, motivo: 'Vencimiento automático');
        suspendidos++;
      }
    }
    return suspendidos;
  }

  /// Obtiene el estado de suscripción de un grupo.
  static Future<SubscriptionStatus> obtenerEstado(String grupoId) async {
    final doc = await _db.collection('grupos').doc(grupoId).get();
    if (!doc.exists) return const SubscriptionStatus.sinDatos();

    final data = doc.data()!;
    return SubscriptionStatus(
      activo: data['activo'] as bool? ?? true,
      suspendido: data['suspendido'] as bool? ?? false,
      fechaPago: (data['fechaPago'] as Timestamp?)?.toDate(),
      fechaVencimiento: (data['fechaVencimiento'] as Timestamp?)?.toDate(),
      valorMensual: data['valorMensual'] as int? ?? 75000,
      historialPagos: (data['historialPagos'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],
    );
  }

  /// Verifica si un grupo puede operar (crear casos, empresas, etc.).
  /// Usar antes de cualquier operación de escritura.
  static Future<bool> puedeOperar(String grupoId) async {
    final doc = await _db.collection('grupos').doc(grupoId).get();
    if (!doc.exists) return false;
    return doc.data()?['activo'] == true;
  }
}

/// Estado de suscripción de un grupo.
class SubscriptionStatus {
  final bool activo;
  final bool suspendido;
  final DateTime? fechaPago;
  final DateTime? fechaVencimiento;
  final int valorMensual;
  final List<Map<String, dynamic>> historialPagos;

  const SubscriptionStatus({
    required this.activo,
    required this.suspendido,
    this.fechaPago,
    this.fechaVencimiento,
    required this.valorMensual,
    required this.historialPagos,
  });

  const SubscriptionStatus.sinDatos()
      : activo = false,
        suspendido = false,
        fechaPago = null,
        fechaVencimiento = null,
        valorMensual = 75000,
        historialPagos = const [];

  int get diasRestantes {
    if (fechaVencimiento == null) return 0;
    final diff = fechaVencimiento!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get vencido =>
      fechaVencimiento != null && DateTime.now().isAfter(fechaVencimiento!);

  bool get proximoAVencer => diasRestantes > 0 && diasRestantes <= 5;
}