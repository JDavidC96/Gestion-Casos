// lib/widgets/closed_state_card_firebase.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ClosedStateCardFirebase extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String descripcionSolucion;
  final String? fotoPath;
  final String? fotoUrl;
  final Uint8List? firma;
  final String? firmaUrl;
  final String? usuarioNombre;
  final bool bloqueado;
  final ValueChanged<String> onDescripcionSolucionChanged;
  final VoidCallback onTomarFoto;
  final VoidCallback onCapturarFirma;
  final VoidCallback onGuardar;
  final bool tomandoFoto;

  const ClosedStateCardFirebase({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.descripcionSolucion,
    this.fotoPath,
    this.fotoUrl,
    this.firma,
    this.firmaUrl,
    this.usuarioNombre,
    required this.bloqueado,
    required this.onDescripcionSolucionChanged,
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
          color: Colors.green.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.withOpacity(0.1),
              Colors.green.withOpacity(0.05),
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
              _buildDescripcionSolucion(),
              const SizedBox(height: 16),
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
        Icon(Icons.lock, color: Colors.green, size: 28),
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

  Widget _buildDescripcionSolucion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Descripción de la solución *",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: onDescripcionSolucionChanged,
          controller: TextEditingController(text: descripcionSolucion)
            ..selection = TextSelection.fromPosition(
                TextPosition(offset: descripcionSolucion.length)),
          maxLines: 4,
          readOnly: bloqueado,
          decoration: InputDecoration(
            hintText: "Describa la solución implementada...",
            border: const OutlineInputBorder(),
            filled: bloqueado,
            fillColor: bloqueado ? Colors.grey[100] : null,
            suffixIcon: bloqueado ? const Icon(Icons.lock) : null,
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
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: onCapturarFirma,
          icon: const Icon(Icons.edit),
          label: const Text("Firma"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.withOpacity(0.8),
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: onGuardar,
          icon: const Icon(Icons.save),
          label: const Text("Guardar"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
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
            child: fotoPath != null && File(fotoPath!).existsSync()
                ? Image.file(
                    File(fotoPath!),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : fotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: fotoUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      )
                    : Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.image)),
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
          child: firma != null
              ? Image.memory(firma!, width: 200, height: 100)
              : firmaUrl != null
                  ? CachedNetworkImage(
                      imageUrl: firmaUrl!,
                      width: 200,
                      height: 100,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}