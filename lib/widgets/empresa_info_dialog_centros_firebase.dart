// lib/widgets/empresa_info_dialog_centros_firebase.dart
import 'package:flutter/material.dart';
import '../models/empresa_model.dart';

class EmpresaInfoDialogCentrosFirebase extends StatelessWidget {
  final Empresa empresa;
  final int cantidadCentros;

  const EmpresaInfoDialogCentrosFirebase({
    super.key,
    required this.empresa,
    required this.cantidadCentros,
  });

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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Centros de Trabajo',
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 12),
          
          // NIT
          _buildInfoRow(
            Icons.badge,
            'NIT',
            empresa.nit,
            Colors.grey[700]!,
          ),
          const SizedBox(height: 16),

          // ID de empresa
          _buildInfoRow(
            Icons.fingerprint,
            'ID Empresa',
            empresa.id.length > 20 
                ? '${empresa.id.substring(0, 20)}...' 
                : empresa.id,
            Colors.grey[500]!,
          ),
          const SizedBox(height: 16),

          const Divider(),
          const SizedBox(height: 12),

          // Centros de trabajo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cantidadCentros > 0 
                  ? Colors.blue.withOpacity(0.1) 
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cantidadCentros > 0 
                    ? Colors.blue.withOpacity(0.3) 
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.location_city,
                  size: 40,
                  color: cantidadCentros > 0 ? Colors.blue : Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  cantidadCentros.toString(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: cantidadCentros > 0 ? Colors.blue : Colors.grey,
                  ),
                ),
                Text(
                  cantidadCentros == 1 
                      ? 'Centro de Trabajo' 
                      : 'Centros de Trabajo',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          if (cantidadCentros == 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No hay centros registrados. Agrega el primer centro.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}