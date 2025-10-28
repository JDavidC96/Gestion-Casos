// widgets/empty_centros_state.dart
import 'package:flutter/material.dart';

class EmptyCentrosState extends StatelessWidget {
  final IconData empresaIcon;
  final VoidCallback onAddCentro;

  const EmptyCentrosState({
    super.key,
    required this.empresaIcon,
    required this.onAddCentro,
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
          const Text(
            'No hay centros de trabajo',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddCentro,
            icon: const Icon(Icons.add),
            label: const Text('Agregar Primer Centro'),
          ),
        ],
      ),
    );
  }
}