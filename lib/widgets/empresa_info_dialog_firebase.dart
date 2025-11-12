// lib/widgets/empresa_info_dialog_firebase.dart
import 'package:flutter/material.dart';
import '../models/empresa_model.dart';

class EmpresaInfoDialogFirebase extends StatelessWidget {
  final Empresa empresa;
  final int cantidadCasos;
  final int casosAbiertos;

  const EmpresaInfoDialogFirebase({
    super.key,
    required this.empresa,
    required this.cantidadCasos,
    required this.casosAbiertos,
  });

  int get casosCerrados => cantidadCasos - casosAbiertos;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(empresa.icon, color: Colors.blue, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empresa.nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Información General',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Divider
            const Divider(),
            const SizedBox(height: 8),

            // NIT
            _buildInfoRow(
              Icons.badge,
              'NIT',
              empresa.nit,
              Colors.grey[700]!,
            ),
            const SizedBox(height: 16),

            // ID (opcional, para debugging)
            _buildInfoRow(
              Icons.fingerprint,
              'ID',
              empresa.id.length > 20 
                  ? '${empresa.id.substring(0, 20)}...' 
                  : empresa.id,
              Colors.grey[500]!,
            ),
            const SizedBox(height: 16),

            // Divider
            const Divider(),
            const SizedBox(height: 8),

            // Header de estadísticas
            Text(
              'Estadísticas de Casos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),

            // Total de casos
            _buildInfoRow(
              Icons.folder,
              'Total de casos',
              cantidadCasos.toString(),
              Colors.blue,
            ),
            const SizedBox(height: 12),

            // Casos abiertos
            _buildInfoRow(
              Icons.folder_open,
              'Casos abiertos',
              casosAbiertos.toString(),
              casosAbiertos > 0 ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 12),

            // Casos cerrados
            _buildInfoRow(
              Icons.check_circle,
              'Casos cerrados',
              casosCerrados.toString(),
              Colors.green,
            ),

            // Barra de progreso visual
            if (cantidadCasos > 0) ...[
              const SizedBox(height: 16),
              _buildProgressBar(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final porcentajeCerrados = cantidadCasos > 0 
        ? (casosCerrados / cantidadCasos) 
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progreso de cierre',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(porcentajeCerrados * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: porcentajeCerrados,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              porcentajeCerrados == 1.0 
                  ? Colors.green 
                  : Colors.orange,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}