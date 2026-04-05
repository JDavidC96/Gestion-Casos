// lib/widgets/subscription_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/subscription_service.dart';

/// Diálogo para gestionar la suscripción de un grupo (consultora SST).
/// Se abre desde el GroupCard o GroupAdminScreen.
class SubscriptionDialog extends StatefulWidget {
  final String grupoId;
  final String grupoNombre;

  const SubscriptionDialog({
    super.key,
    required this.grupoId,
    required this.grupoNombre,
  });

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog> {
  SubscriptionStatus? _status;
  bool _loading = true;
  bool _procesando = false;
  final _notaCtrl = TextEditingController();
  final _montoCtrl = TextEditingController(text: '75000');
  final _formatoCOP = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final _formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final status = await SubscriptionService.obtenerEstado(widget.grupoId);
      if (mounted) setState(() { _status = status; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registrarPago() async {
    final monto = int.tryParse(
        _montoCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 75000;

    setState(() => _procesando = true);
    try {
      await SubscriptionService.registrarPago(
        grupoId: widget.grupoId,
        monto: monto,
        nota: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Pago de ${_formatoCOP.format(monto)} registrado — ${widget.grupoNombre} activo por 30 días'),
            backgroundColor: Colors.green,
          ),
        );
        _notaCtrl.clear();
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _suspender() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Suspender grupo'),
        content: Text(
            '¿Suspender "${widget.grupoNombre}"?\n\n'
            'El grupo podrá ver sus datos pero no crear casos, '
            'empresas ni centros de trabajo hasta que se registre un nuevo pago.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Suspender', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _procesando = true);
    try {
      await SubscriptionService.suspenderGrupo(widget.grupoId,
          motivo: 'Suspensión manual');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${widget.grupoNombre} suspendido'),
              backgroundColor: Colors.orange),
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _reactivar() async {
    setState(() => _procesando = true);
    try {
      await SubscriptionService.reactivarGrupo(widget.grupoId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${widget.grupoNombre} reactivado'),
              backgroundColor: Colors.green),
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final s = _status!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: s.activo ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Icon(
                s.activo ? Icons.verified : Icons.block,
                size: 40,
                color: s.activo ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 8),
              Text(
                widget.grupoNombre,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: s.activo ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.suspendido
                      ? 'SUSPENDIDO'
                      : s.activo
                          ? 'ACTIVO'
                          : 'INACTIVO',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // ── Body scrollable ──
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Info de suscripción ──
                _buildInfoCard(s),
                const SizedBox(height: 16),

                // ── Registrar pago ──
                const Text('Registrar pago',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _montoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monto (COP)',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    hintText: 'Ej: Transferencia Bancolombia, Nequi...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _procesando ? null : _registrarPago,
                    icon: _procesando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.payment),
                    label: const Text('Registrar Pago'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Acciones ──
                Row(
                  children: [
                    if (s.activo)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _procesando ? null : _suspender,
                          icon: const Icon(Icons.pause_circle, size: 18),
                          label: const Text('Suspender'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _procesando ? null : _reactivar,
                          icon: const Icon(Icons.play_circle, size: 18),
                          label: const Text('Reactivar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),

                // ── Historial de pagos ──
                if (s.historialPagos.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Historial de pagos',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...s.historialPagos.reversed.take(10).map((pago) {
                    final fecha = pago['fecha'];
                    DateTime? dt;
                    if (fecha is DateTime) {
                      dt = fecha;
                    } else if (fecha != null) {
                      try {
                        dt = (fecha as dynamic).toDate() as DateTime;
                      } catch (_) {}
                    }
                    final monto = pago['monto'] as int? ?? 0;
                    final nota = pago['nota'] as String? ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long,
                              size: 18, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatoCOP.format(monto),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                if (nota.isNotEmpty)
                                  Text(nota,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          Text(
                            dt != null ? _formatoFecha.format(dt) : '—',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),

        // ── Footer ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(SubscriptionStatus s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _infoRow('Valor mensual', _formatoCOP.format(s.valorMensual)),
          if (s.fechaPago != null)
            _infoRow('Último pago', _formatoFecha.format(s.fechaPago!)),
          if (s.fechaVencimiento != null) ...[
            _infoRow('Vencimiento', _formatoFecha.format(s.fechaVencimiento!)),
            _infoRow(
              'Días restantes',
              s.vencido
                  ? 'VENCIDO'
                  : '${s.diasRestantes} días',
              valueColor: s.vencido
                  ? Colors.red
                  : s.proximoAVencer
                      ? Colors.orange
                      : Colors.green,
            ),
          ],
          _infoRow('Total pagos', '${s.historialPagos.length}'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              )),
        ],
      ),
    );
  }
}