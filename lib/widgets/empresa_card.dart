// widgets/empresa_card.dart - VERSIÓN ACTUALIZADA
import 'package:flutter/material.dart';
import '../models/empresa_model.dart';

class EmpresaCard extends StatelessWidget {
  final Empresa empresa;
  final int totalCasos;
  final int casosAbiertos;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool puedeEditar;

  const EmpresaCard({
    super.key,
    required this.empresa,
    required this.totalCasos,
    required this.casosAbiertos,
    required this.onTap,
    required this.onLongPress,
    this.puedeEditar = true,
  });

  bool get _tieneCasosAbiertos => casosAbiertos > 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: puedeEditar ? onLongPress : null,
      child: Card(
        color: _tieneCasosAbiertos ? Colors.orange[50] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _tieneCasosAbiertos ? Colors.orange : Colors.transparent,
            width: 2,
          ),
        ),
        elevation: 6,
        child: Stack(
          children: [
            _buildCardContent(),
            _buildCaseCountBadge(),
            if (!puedeEditar) _buildReadOnlyBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            empresa.icon,
            size: 50,
            color: _tieneCasosAbiertos ? Colors.orange : Colors.blue,
          ),
          const SizedBox(height: 12),
          Text(
            empresa.nombre,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _tieneCasosAbiertos ? Colors.orange[800] : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'NIT: ${empresa.nit}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          if (_tieneCasosAbiertos) _buildOpenCasesBadge(),
        ],
      ),
    );
  }

  Widget _buildOpenCasesBadge() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$casosAbiertos caso${casosAbiertos > 1 ? 's' : ''} abierto${casosAbiertos > 1 ? 's' : ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaseCountBadge() {
    return Positioned(
      right: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _tieneCasosAbiertos ? Colors.orange : Colors.green,
          shape: BoxShape.circle,
        ),
        child: Text(
          totalCasos.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyBadge() {
    return Positioned(
      left: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Solo lectura',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}