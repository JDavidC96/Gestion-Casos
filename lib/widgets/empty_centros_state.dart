// lib/widgets/empty_centros_state.dart
import 'package:flutter/material.dart';

class EmptyCentrosState extends StatelessWidget {
  final IconData empresaIcon;
  final VoidCallback onAddCentro;
  final bool puedeAgregar;

  const EmptyCentrosState({
    super.key,
    required this.empresaIcon,
    required this.onAddCentro,
    this.puedeAgregar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              empresaIcon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No hay centros de trabajo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Los centros de trabajo te permiten organizar los casos por ubicaciones específicas dentro de la empresa.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            if (puedeAgregar)
              ElevatedButton.icon(
                onPressed: onAddCentro,
                icon: const Icon(Icons.add),
                label: const Text('Agregar Primer Centro'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color.fromARGB(255, 172, 163, 163)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.lock, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text(
                      'Sin permisos de edición',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contacta al administrador para agregar centros',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}