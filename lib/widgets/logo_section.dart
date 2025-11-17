// lib/widgets/logo_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/admin_controller.dart';

class LogoSection extends StatelessWidget {
  final String? grupoId;
  final String? grupoNombre;
  final VoidCallback onChangeLogo;
  final VoidCallback onDeleteLogo;
  final VoidCallback? onConfigureInterface; // Nuevo parámetro
  
  const LogoSection({
    super.key,
    this.grupoId,
    this.grupoNombre,
    required this.onChangeLogo,
    required this.onDeleteLogo,
    this.onConfigureInterface, // Nuevo parámetro opcional
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, controller, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildLogoPreview(controller),
                  const SizedBox(height: 16),
                  _buildActionButtons(controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.business, color: Colors.purple, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Logo de la Empresa',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              Text(
                grupoNombre ?? 'Sin nombre de grupo',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildLogoPreview(AdminController controller) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: controller.loadingLogo
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : controller.logoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    controller.logoUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const _LogoPlaceholder(
                        icon: Icons.broken_image,
                        text: 'Error cargando\nlogo',
                      );
                    },
                  ),
                )
              : const _LogoPlaceholder(
                  icon: Icons.business,
                  text: 'Sin logo',
                ),
    );
  }
  
  Widget _buildActionButtons(AdminController controller) {
    return Column(
      children: [
        if (onConfigureInterface != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onConfigureInterface,
                  icon: const Icon(Icons.settings, size: 20),
                  label: const Text('Configurar Interfaz'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onChangeLogo,
                icon: const Icon(Icons.upload, size: 20),
                label: const Text('Cambiar Logo'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (controller.logoUrl != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDeleteLogo,
                  icon: const Icon(Icons.delete, size: 20),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;
  
  const _LogoPlaceholder({
    required this.icon,
    required this.text,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.grey, size: 40),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}