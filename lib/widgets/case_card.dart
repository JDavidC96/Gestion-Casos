// widgets/case_card.dart
import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../data/risk_data.dart';

class CaseCard extends StatelessWidget {
  final Case caso;
  final VoidCallback onTap;

  const CaseCard({
    super.key,
    required this.caso,
    required this.onTap,
  });

  IconData _getCaseIcon() {
    return tiposDePeligro.firstWhere(
      (item) => item["tipo"] == caso.tipoRiesgo,
      orElse: () => {"icon": Icons.help},
    )["icon"];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getCaseIcon(),
            color: Colors.orange,
            size: 24,
          ),
        ),
        title: Text(
          caso.nombre,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caso.descripcionRiesgo),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    caso.tipoRiesgo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Creado: ${_formatDate(caso.fechaCreacion)}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.radio_button_unchecked, color: Colors.orange),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}