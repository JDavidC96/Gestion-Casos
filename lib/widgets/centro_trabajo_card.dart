// lib/widgets/centro_trabajo_card.dart - VERSIÓN ACTUALIZADA
import 'package:flutter/material.dart';
import '../models/centro_trabajo_model.dart';

class CentroTrabajoCard extends StatelessWidget {
  final CentroTrabajo centro;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool puedeEditar;

  const CentroTrabajoCard({
    super.key,
    required this.centro,
    required this.onTap,
    required this.onLongPress,
    this.puedeEditar = true,
  });

  IconData _getIconForType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'oficina':
        return Icons.business;
      case 'fabrica':
        return Icons.factory;
      case 'bodega':
        return Icons.warehouse;
      case 'planta':
        return Icons.precision_manufacturing;
      case 'taller':
        return Icons.build;
      case 'almacen':
        return Icons.inventory;
      case 'centro de distribucion':
        return Icons.local_shipping;
      case 'punto de venta':
        return Icons.store;
      case 'sede principal':
        return Icons.corporate_fare;
      default:
        return Icons.business_center;
    }
  }

  Color _getColorForType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'oficina':
        return Colors.blue;
      case 'fábrica':
      case 'fabrica':
        return Colors.orange;
      case 'bodega':
        return Colors.brown;
      case 'planta':
        return Colors.green;
      case 'taller':
        return Colors.deepPurple;
      case 'almacén':
      case 'almacen':
        return Colors.teal;
      case 'centro de distribución':
      case 'centro de distribucion':
        return Colors.indigo;
      case 'punto de venta':
        return Colors.pink;
      case 'sede principal':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _getColorForType(centro.tipo);
    final iconData = _getIconForType(centro.tipo);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: puedeEditar ? onLongPress : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono del tipo de centro
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  size: 28,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 16),
              // Información del centro
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      centro.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      centro.direccion,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: iconColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        centro.tipo,
                        style: TextStyle(
                          fontSize: 12,
                          color: iconColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Indicador de permisos
              if (!puedeEditar)
                const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}