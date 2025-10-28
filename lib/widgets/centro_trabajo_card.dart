// widgets/centro_trabajo_card.dart
import 'package:flutter/material.dart';
import '../models/centro_trabajo_model.dart';
import '../utils/icon_utils.dart';

class CentroTrabajoCard extends StatelessWidget {
  final CentroTrabajo centro;
  final VoidCallback onTap;

  const CentroTrabajoCard({
    super.key,
    required this.centro,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          IconUtils.getIconPorTipo(centro.tipo),
          color: Colors.blue,
        ),
        title: Text(centro.nombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(centro.direccion),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                centro.tipo,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}