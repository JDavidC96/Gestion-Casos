// widgets/case_state_card.dart
import 'package:flutter/material.dart';
import '../models/case_detail_data.dart';
import './risk_level_selector.dart';

class CaseStateCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final CaseDetailData data;
  final bool esEstadoAbierto;
  final bool bloqueado;
  final Color colorFondo;
  final ValueChanged<String> onDescripcionChanged;
  final ValueChanged<String?> onnivelPeligroChanged;
  final ValueChanged<String>? onRecomendacionesChanged;
  final VoidCallback onTomarFoto;
  final VoidCallback onCapturarFirma;
  final VoidCallback onGuardar;
  final bool tomandoFoto;

  const CaseStateCard({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.data,
    required this.esEstadoAbierto,
    required this.bloqueado,
    required this.colorFondo,
    required this.onDescripcionChanged,
    required this.onnivelPeligroChanged,
    this.onRecomendacionesChanged,
    required this.onTomarFoto,
    required this.onCapturarFirma,
    required this.onGuardar,
    required this.tomandoFoto,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Color.alphaBlend(colorFondo.withAlpha(77), Colors.transparent),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(colorFondo.withAlpha(25), Colors.white),
              Color.alphaBlend(colorFondo.withAlpha(12), Colors.white),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 20),

              // Descripción del hallazgo
              _buildDescripcionHallazgo(),
              const SizedBox(height: 16),

              // Nivel de peligro
              RiskLevelSelector(
                nivelSeleccionado: data.nivelPeligro,
                onChanged: bloqueado ? _onnivelPeligroDisabled : onnivelPeligroChanged,
                enabled: !bloqueado,
              ),
              const SizedBox(height: 16),

              // Recomendaciones de control (solo para estado abierto)
              if (esEstadoAbierto && !bloqueado) _buildRecomendacionesControl(),
              if (esEstadoAbierto && !bloqueado) const SizedBox(height: 16),

              // Botones de acción
              if (!bloqueado) _buildActionButtons(),
              if (!bloqueado) const SizedBox(height: 16),

              // Previews de foto y firma
              if (data.foto != null) _buildFotoPreview(),
              if (data.firma != null) _buildFirmaPreview(),
            ],
          ),
        ),
      ),
    );
  }

  // Función dummy para cuando el selector está deshabilitado
  void _onnivelPeligroDisabled(String? value) {
    // No hacer nada cuando está bloqueado
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          titulo.contains("Abierto") ? Icons.lock_open : Icons.lock,
          color: colorFondo,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                subtitulo,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (bloqueado)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  "Guardado",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDescripcionHallazgo() {
    final controller = TextEditingController();
    
    // Usar un post-frame callback para establecer el texto después de la construcción
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (data.descripcionHallazgo.isNotEmpty) {
        controller.text = data.descripcionHallazgo;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length)
        );
      }
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Descripción del hallazgo *",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: onDescripcionChanged,
          controller: controller,
          maxLines: 4,
          readOnly: bloqueado,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            hintText: "Describa el hallazgo encontrado...",
            border: const OutlineInputBorder(),
            filled: bloqueado,
            fillColor: bloqueado ? Colors.grey[100] : null,
            suffixIcon: bloqueado ? const Icon(Icons.lock) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildRecomendacionesControl() {
    final controller = TextEditingController();
    
    // Usar un post-frame callback para establecer el texto después de la construcción
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (data.recomendacionesControl != null && data.recomendacionesControl!.isNotEmpty) {
        controller.text = data.recomendacionesControl!;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length)
        );
      }
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recomendaciones de control",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: onRecomendacionesChanged ?? (value) {},
          controller: controller,
          maxLines: 3,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            hintText: "Ingrese las recomendaciones de los inspectores...",
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ElevatedButton.icon(
          onPressed: tomandoFoto ? null : onTomarFoto,
          icon: tomandoFoto 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt),
          label: tomandoFoto ? const Text("Tomando...") : const Text("Tomar Foto"),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorFondo,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: onCapturarFirma,
          icon: const Icon(Icons.edit),
          label: const Text("Firma"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _withOpacity(colorFondo, 0.8),
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: onGuardar,
          icon: const Icon(Icons.save),
          label: const Text("Guardar"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFotoPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          "Foto:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _withOpacity(Colors.black, 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              data.foto!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFirmaPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          "Firma:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.memory(data.firma!, width: 200, height: 100),
        ),
      ],
    );
  }

  Color _withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
}