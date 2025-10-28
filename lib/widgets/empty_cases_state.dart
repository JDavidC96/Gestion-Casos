// widgets/empty_cases_state.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EmptyCasesState extends StatelessWidget {
  final IconData empresaIcon;
  final String empresaNombre;
  final int casosCerradosCount;
  final VoidCallback onAddCase;
  final VoidCallback onViewClosedCases;

  const EmptyCasesState({
    super.key,
    required this.empresaIcon,
    required this.empresaNombre,
    required this.casosCerradosCount,
    required this.onAddCase,
    required this.onViewClosedCases,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            empresaIcon,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay casos abiertos para $empresaNombre',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (casosCerradosCount > 0) ...[
            const SizedBox(height: 16),
            Text(
              '$casosCerradosCount caso(s) cerrado(s)',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onViewClosedCases,
              icon: const Icon(Icons.archive),
              label: const Text('Ver Casos Cerrados'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddCase,
            icon: const Icon(FontAwesomeIcons.plus),
            label: const Text('Agregar Primer Caso'),
          ),
        ],
      ),
    );
  }
}