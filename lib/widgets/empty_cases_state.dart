// lib/widgets/empty_cases_state.dart - VERSIÓN ACTUALIZADA
import 'package:flutter/material.dart';

class EmptyCasesState extends StatelessWidget {
  final IconData empresaIcon;
  final String empresaNombre;
  final String? centroNombre;
  final int casosCerradosCount;
  final VoidCallback onAddCase;
  final VoidCallback onViewClosedCases;
  final bool puedeAgregar;

  const EmptyCasesState({
    super.key,
    required this.empresaIcon,
    required this.empresaNombre,
    this.centroNombre,
    required this.casosCerradosCount,
    required this.onAddCase,
    required this.onViewClosedCases,
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
              'No hay casos abiertos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              centroNombre ?? empresaNombre,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Los casos te permiten registrar y hacer seguimiento a riesgos identificados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 32),
            if (puedeAgregar)
              ElevatedButton.icon(
                onPressed: onAddCase,
                icon: const Icon(Icons.add),
                label: const Text('Crear Primer Caso'),
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
                  border: Border.all(color: const Color.fromARGB(255, 224, 224, 224)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.lock, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text(
                      'Sin permisos de creación',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contacta al administrador para crear casos',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            if (casosCerradosCount > 0) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[100]!),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      '$casosCerradosCount caso${casosCerradosCount > 1 ? 's' : ''} cerrado${casosCerradosCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: onViewClosedCases,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Ver Casos Cerrados'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}