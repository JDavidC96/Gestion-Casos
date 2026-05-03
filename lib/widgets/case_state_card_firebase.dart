// lib/widgets/case_state_card_firebase.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'risk_level_selector.dart';

class CaseStateCardFirebase extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final String descripcionHallazgo;
  final String nivelPeligro;
  final String? recomendacionesControl;
  final String? fotoPath;
  final String? fotoUrl;
  final Uint8List? firma;           // firma automática del inspector
  final String? firmaUrl;
  final String? usuarioNombre;
  final bool bloqueado;
  final ValueChanged<String> onDescripcionChanged;
  final ValueChanged<String?> onnivelPeligroChanged;
  final ValueChanged<String>? onRecomendacionesChanged;
  final ValueChanged<String>? onUbicacionChanged;
  final TextEditingController? ubicacionController;
  final VoidCallback onTomarFoto;
  final VoidCallback onGuardar;
  final bool tomandoFoto;
  final bool subiendoFoto;

  // Parámetros de configuración del grupo
  final bool habilitarFotos;
  final bool habilitarFirmas;
  final bool mostrarNivelPeligro;

  // Modo texto libre: el inspector describe el peligro sin seleccionar catálogo
  final bool modoTextoLibrePeligro;
  final String? tipoPeligroLibre;
  final ValueChanged<String>? onTipoPeligroLibreChanged;

  // Firma del cliente (nuevos)
  final ValueChanged<Uint8List?>? onFirmaClienteChanged;
  final ValueChanged<String>? onNombreClienteChanged;
  final Uint8List? firmaCliente;
  final String? nombreCliente;

  const CaseStateCardFirebase({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.descripcionHallazgo,
    required this.nivelPeligro,
    this.recomendacionesControl,
    this.fotoPath,
    this.fotoUrl,
    this.firma,
    this.firmaUrl,
    this.usuarioNombre,
    required this.bloqueado,
    required this.onDescripcionChanged,
    required this.onnivelPeligroChanged,
    this.onRecomendacionesChanged,
    this.onUbicacionChanged,
    required this.ubicacionController,
    required this.onTomarFoto,
    required this.onGuardar,
    required this.tomandoFoto,
    this.subiendoFoto = false,
    this.onFirmaClienteChanged,
    this.onNombreClienteChanged,
    this.firmaCliente,
    this.nombreCliente,
    this.habilitarFotos = true,
    this.habilitarFirmas = true,
    this.mostrarNivelPeligro = true,
    this.modoTextoLibrePeligro = false,
    this.tipoPeligroLibre,
    this.onTipoPeligroLibreChanged,
  });

  @override
  State<CaseStateCardFirebase> createState() => _CaseStateCardFirebaseState();
}

class _CaseStateCardFirebaseState extends State<CaseStateCardFirebase> {
  late final SignatureController _sigController;
  late final TextEditingController _nombreClienteCtrl;
  bool _firmaClienteLimpia = true;

  @override
  void initState() {
    super.initState();
    _sigController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _nombreClienteCtrl = TextEditingController(text: widget.nombreCliente ?? '');
    // true = el usuario NO ha dibujado en el canvas esta sesión.
    // Si hay firma de draft, se muestra como preview (no en el canvas).
    _firmaClienteLimpia = true;

    _sigController.addListener(() {
      if (_sigController.isNotEmpty) {
        setState(() => _firmaClienteLimpia = false);
        _exportarFirmaCliente();
      }
    });
  }

  @override
  void dispose() {
    _sigController.dispose();
    _nombreClienteCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CaseStateCardFirebase oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincronizar el TextEditingController cuando el padre provee un nuevo valor
    if (widget.nombreCliente != oldWidget.nombreCliente &&
        widget.nombreCliente != null &&
        _nombreClienteCtrl.text != widget.nombreCliente) {
      _nombreClienteCtrl.text = widget.nombreCliente!;
    }
    // NO cambiar _firmaClienteLimpia aquí — solo el listener del canvas
    // debe ponerlo en false (cuando el usuario dibuja).
  }

  Future<void> _exportarFirmaCliente() async {
    final bytes = await _sigController.toPngBytes();
    widget.onFirmaClienteChanged?.call(bytes);
  }

  void _limpiarFirmaCliente() {
    _sigController.clear();
    setState(() => _firmaClienteLimpia = true);
    widget.onFirmaClienteChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.blue.withOpacity(0.3), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withOpacity(0.1),
              Colors.blue.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildDescripcionHallazgo(),
              const SizedBox(height: 16),
              _buildUbicacionField(),
              const SizedBox(height: 16),
              if (widget.modoTextoLibrePeligro) ...[
                _buildTipoPeligroLibreField(),
                const SizedBox(height: 16),
              ] else if (widget.mostrarNivelPeligro) ...[
                RiskLevelSelector(
                  nivelSeleccionado: widget.nivelPeligro,
                  onChanged: widget.bloqueado ? null : widget.onnivelPeligroChanged,
                  enabled: !widget.bloqueado,
                ),
                const SizedBox(height: 16),
              ],
              _buildRecomendacionesControl(),
              const SizedBox(height: 16),
              if (widget.habilitarFirmas && widget.firma != null && widget.usuarioNombre != null)
                _buildFirmaInspectorInfo(),
              if (widget.habilitarFirmas) const SizedBox(height: 16),
              if (widget.habilitarFirmas) _buildFirmaClienteSection(),
              const SizedBox(height: 16),
              if (!widget.bloqueado) _buildActionButtons(),
              if (!widget.bloqueado) const SizedBox(height: 16),
              if (widget.habilitarFotos && (widget.fotoPath != null || widget.fotoUrl != null))
                _buildFotoPreview(),
              if (widget.habilitarFirmas && widget.firma != null) _buildFirmaInspectorPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.lock_open, color: Colors.blue, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.titulo,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              Text(widget.subtitulo,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
        ),
        if (widget.bloqueado)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.green, borderRadius: BorderRadius.circular(20)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text("Guardado",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTipoPeligroLibreField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de peligro *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: widget.onTipoPeligroLibreChanged,
          controller: TextEditingController(text: widget.tipoPeligroLibre ?? '')
            ..selection = TextSelection.fromPosition(
                TextPosition(offset: (widget.tipoPeligroLibre ?? '').length)),
          readOnly: widget.bloqueado,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Describa el tipo de peligro identificado...',
            border: const OutlineInputBorder(),
            filled: widget.bloqueado,
            fillColor: widget.bloqueado ? Colors.grey[100] : null,
            suffixIcon: widget.bloqueado ? const Icon(Icons.lock) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDescripcionHallazgo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Descripción del hallazgo *",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          onChanged: widget.onDescripcionChanged,
          controller: TextEditingController(text: widget.descripcionHallazgo)
            ..selection = TextSelection.fromPosition(
                TextPosition(offset: widget.descripcionHallazgo.length)),
          maxLines: 4,
          readOnly: widget.bloqueado,
          decoration: InputDecoration(
            hintText: "Describa el hallazgo encontrado...",
            border: const OutlineInputBorder(),
            filled: widget.bloqueado,
            fillColor: widget.bloqueado ? Colors.grey[100] : null,
            suffixIcon: widget.bloqueado ? const Icon(Icons.lock) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildUbicacionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Ubicación *",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          onChanged: widget.onUbicacionChanged ?? (v) {},
          controller: widget.ubicacionController,
          maxLines: 2,
          readOnly: widget.bloqueado,
          decoration: InputDecoration(
            hintText: "Ej: Parqueadero, Área de producción...",
            border: const OutlineInputBorder(),
            filled: widget.bloqueado,
            fillColor: widget.bloqueado ? Colors.grey[100] : null,
            suffixIcon: widget.bloqueado ? const Icon(Icons.lock) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildRecomendacionesControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Recomendaciones de control",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          onChanged: widget.onRecomendacionesChanged ?? (v) {},
          controller:
              TextEditingController(text: widget.recomendacionesControl ?? '')
                ..selection = TextSelection.fromPosition(TextPosition(
                    offset: (widget.recomendacionesControl ?? '').length)),
          maxLines: 3,
          readOnly: widget.bloqueado,
          decoration: InputDecoration(
            hintText: "Ingrese las recomendaciones de los inspectores...",
            border: const OutlineInputBorder(),
            filled: widget.bloqueado,
            fillColor: widget.bloqueado ? Colors.grey[100] : null,
            suffixIcon: widget.bloqueado ? const Icon(Icons.lock) : null,
          ),
        ),
      ],
    );
  }

  // ─── FIRMA INSPECTOR ───────────────────────────────────────────────────────

  Widget _buildFirmaInspectorInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user, color: Colors.green[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Firma del inspector",
                    style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text("Responsable: ${widget.usuarioNombre}",
                    style: TextStyle(color: Colors.green[600], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirmaInspectorPreview() {
    if (widget.firma == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text("Firma inspector:",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          width: 250,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(widget.firma!, fit: BoxFit.contain),
              ),
              if (widget.usuarioNombre != null)
                Positioned(
                  bottom: 4,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(widget.usuarioNombre!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── FIRMA DEL CLIENTE ─────────────────────────────────────────────────────

  Widget _buildFirmaClienteSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.draw, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Text(
                "Firma del cliente (opcional)",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.orange[800]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nombre del cliente
          TextField(
            controller: _nombreClienteCtrl,
            readOnly: widget.bloqueado,
            onChanged: (v) => widget.onNombreClienteChanged?.call(v),
            decoration: InputDecoration(
              labelText: "Nombre del cliente",
              hintText: "Escribe el nombre aquí...",
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person_outline),
              filled: widget.bloqueado,
              fillColor: widget.bloqueado ? Colors.grey[100] : null,
              suffixIcon: widget.bloqueado ? const Icon(Icons.lock) : null,
            ),
          ),
          const SizedBox(height: 12),

          // Canvas, preview de firma restaurada, o firma guardada
          if (widget.bloqueado && widget.firmaCliente != null)
            _buildFirmaClienteGuardada()
          else if (!widget.bloqueado && widget.firmaCliente != null && _firmaClienteLimpia)
            // Firma restaurada desde draft — mostrar preview con opción de re-firmar
            _buildFirmaClienteRestaurada()
          else if (!widget.bloqueado)
            _buildCanvasFirma(),
        ],
      ),
    );
  }

  Widget _buildCanvasFirma() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Firma:",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange[300]!),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Signature(
              controller: _sigController,
              height: 150,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              _firmaClienteLimpia ? "Área de firma" : "✓ Firma capturada",
              style: TextStyle(
                  fontSize: 11,
                  color: _firmaClienteLimpia
                      ? Colors.grey[500]
                      : Colors.green[700]),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _limpiarFirmaCliente,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Limpiar", style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.orange[700],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFirmaClienteGuardada() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Firma:",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          width: 250,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange[300]!),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(widget.firmaCliente!, fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }

  /// Muestra la firma restaurada desde el draft con opción de re-firmar.
  Widget _buildFirmaClienteRestaurada() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Firma:",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          width: 250,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green[300]!),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(widget.firmaCliente!, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text("✓ Firma capturada",
                style: TextStyle(fontSize: 11, color: Colors.green[700])),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                // Limpiar firma restaurada y mostrar canvas vacío
                setState(() => _firmaClienteLimpia = true);
                widget.onFirmaClienteChanged?.call(null);
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text("Re-firmar", style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.orange[700],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── BOTONES ───────────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (widget.habilitarFotos)
          ElevatedButton.icon(
            onPressed: (widget.tomandoFoto || widget.subiendoFoto) ? null : widget.onTomarFoto,
            icon: (widget.tomandoFoto || widget.subiendoFoto)
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.camera_alt),
            label: widget.tomandoFoto
                ? const Text("Tomando...")
                : widget.subiendoFoto
                    ? const Text("Subiendo...")
                    : const Text("Tomar Foto"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, foregroundColor: Colors.white),
          ),
        // Botón "Firma" eliminado — era no-op
        ElevatedButton.icon(
          onPressed: widget.onGuardar,
          icon: const Icon(Icons.save),
          label: const Text("Guardar"),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  // ─── FOTO ──────────────────────────────────────────────────────────────────

  Widget _buildFotoPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text("Foto:",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImageWidget(),
          ),
        ),
      ],
    );
  }

  Widget _buildImageWidget() {
    if (widget.fotoPath != null && File(widget.fotoPath!).existsSync()) {
      return Image.file(File(widget.fotoPath!),
          width: double.infinity, height: 200, fit: BoxFit.cover);
    }
    if (widget.fotoUrl != null && widget.fotoUrl!.isNotEmpty) {
      return Image.network(
        widget.fotoUrl!,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, _) => Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 8),
              Text('Error al cargar imagen',
                  style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }
    return Container(
      height: 200,
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No hay foto'),
          ],
        ),
      ),
    );
  }
}