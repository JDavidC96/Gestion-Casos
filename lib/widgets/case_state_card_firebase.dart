// lib/widgets/case_state_card_firebase.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/risk_level_selector.dart';

class CaseStateCardFirebase extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String descripcionHallazgo;
  final String nivelRiesgo;
  final String? recomendacionesControl;
  final String? fotoPath;
  final String? fotoUrl;
  final Uint8List? firma;
  final String? firmaUrl; // Ya no se usa, pero lo dejamos por compatibilidad
  final bool bloqueado;
  final ValueChanged<String> onDescripcionChanged;
  final ValueChanged<String?> onNivelRiesgoChanged;
  final ValueChanged<String>? onRecomendacionesChanged;
  final VoidCallback onTomarFoto;
  final VoidCallback onCapturarFirma;
  final VoidCallback onGuardar;
  final bool tomandoFoto;

  const CaseStateCardFirebase({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.descripcionHallazgo,
    required this.nivelRiesgo,
    this.recomendacionesControl,
    this.fotoPath,
    this.fotoUrl,
    this.firma,
    this.firmaUrl,
    required this.bloqueado,
    required this.onDescripcionChanged,
    required this.onNivelRiesgoChanged,
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
          color: Colors.blue.withOpacity(0.3),
          width: 2,
        ),
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
              RiskLevelSelector(
                nivelSeleccionado: nivelRiesgo,
                onChanged: bloqueado ? null : onNivelRiesgoChanged,
                enabled: !bloqueado,
              ),
              const SizedBox(height: 16),
              if (!bloqueado) _buildRecomendacionesControl(),
              if (!bloqueado) const SizedBox(height: 16),
              if (!bloqueado) _buildActionButtons(),
              if (!bloqueado) const SizedBox(height: 16),
              if (fotoPath != null || fotoUrl != null) _buildFotoPreview(),
              if (firma != null || firmaUrl != null) _buildFirmaPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.lock_open, color: Colors.blue, size: 28),
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
          controller: TextEditingController(text: descripcionHallazgo)
            ..selection = TextSelection.fromPosition(
                TextPosition(offset: descripcionHallazgo.length)),
          maxLines: 4,
          readOnly: bloqueado,
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
          controller: TextEditingController(text: recomendacionesControl ?? '')
            ..selection = TextSelection.fromPosition(
                TextPosition(offset: (recomendacionesControl ?? '').length)),
          maxLines: 3,
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
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: onCapturarFirma,
          icon: const Icon(Icons.edit),
          label: const Text("Firma"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.withOpacity(0.8),
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
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
    // Prioridad 1: Mostrar desde archivo local si existe
    if (fotoPath != null && File(fotoPath!).existsSync()) {
      return Image.file(
        File(fotoPath!),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      );
    }
    
    // Prioridad 2: Mostrar desde URL de Google Drive
    if (fotoUrl != null && fotoUrl!.isNotEmpty) {
      return Image.network(
        fotoUrl!,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error cargando imagen: $error');
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey[300],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 8),
                Text(
                  'Error al cargar imagen',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    // Intentar abrir en navegador
                    print('URL de la foto: $fotoUrl');
                  },
                  child: const Text('Ver detalles'),
                ),
              ],
            ),
          );
        },
      );
    }
    
    // No hay foto
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

  Widget _buildFirmaPreview() {
    // Solo mostrar si hay firma en bytes
    if (firma == null) return const SizedBox.shrink();
    
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
          width: 250,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              firma!,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}