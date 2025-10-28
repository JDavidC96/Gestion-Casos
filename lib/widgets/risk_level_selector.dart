// widgets/risk_level_selector.dart
import 'package:flutter/material.dart';
import '../data/risk_levels_data.dart';

class RiskLevelSelector extends StatelessWidget {
  final String? nivelSeleccionado;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  const RiskLevelSelector({
    super.key,
    required this.nivelSeleccionado,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Nivel de riesgo *",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: nivelSeleccionado,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          isExpanded: true,
          items: RiskLevelsData.nivelesRiesgo.map((nivel) {
            return DropdownMenuItem<String>(
              value: nivel["nivel"],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: nivel["color"],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nivel["nivel"],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "- ${nivel["descripcion"]}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor selecciona un nivel de riesgo';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        
        // Leyenda de siglas fuera del dropdown
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Text(
            "Leyenda: EL = Enfermedad Laboral, IPP = Incapacidad Permanente Parcial, I = Invalidez, M = Muerte",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}