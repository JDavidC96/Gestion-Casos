// widgets/case_card.dart - VERSIÓN ACTUALIZADA Y COMPATIBLE
import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../data/risk_data.dart';

class CaseCard extends StatelessWidget {
  final Case caso;
  final VoidCallback onTap;
  final bool mostrarNivelRiesgo;
  final Color? nivelRiesgoColor;

  const CaseCard({
    super.key,
    required this.caso,
    required this.onTap,
    this.mostrarNivelRiesgo = true,
    this.nivelRiesgoColor,
  });

  IconData _getCaseIcon() {
    // Usar el nuevo método de RiskData para compatibilidad
    return RiskData.getIconPorCategoria(caso.tipoRiesgo);
  }

  Color _getnivelPeligroColor(String nivel) {
    switch (nivel) {
      case 'Bajo':
        return Colors.green;
      case 'Medio':
        return Colors.orange;
      case 'Alto':
        return Colors.red[400]!;
      default:
        return Colors.grey;
    }
  }

  Color _getTipoRiesgoColor(String tipo) {
    // Usar el nuevo método de RiskData
    return RiskData.getColorPorCategoria(tipo);
  }

  @override
  Widget build(BuildContext context) {
    final tipoColor = _getTipoRiesgoColor(caso.tipoRiesgo);
    final nivelColor = nivelRiesgoColor ?? _getnivelPeligroColor(caso.nivelPeligro);
    final caseIcon = _getCaseIcon();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono principal con color del Tipo de Peligro
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tipoColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  caseIcon,
                  color: tipoColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Contenido del caso
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título del caso
                    Text(
                      caso.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    
                    // Descripción del riesgo
                    Text(
                      caso.descripcionRiesgo,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Mostrar subgrupo si está disponible
                    if (caso.subgrupoRiesgo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tipo: ${caso.subgrupoRiesgo}',
                        style: TextStyle(
                          fontSize: 12,
                          color: tipoColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    const SizedBox(height: 10),
                    
                    // Chips de información
                    Row(
                      children: [
                        // Tipo de Peligro
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: tipoColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tipoColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                caseIcon,
                                size: 12,
                                color: tipoColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                caso.tipoRiesgo,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tipoColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Nivel de peligro - SOLO SI ESTÁ HABILITADO
                        if (mostrarNivelRiesgo && caso.nivelPeligro.isNotEmpty && caso.nivelPeligro != 'No aplica')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: nivelColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: nivelColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: nivelColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  caso.nivelPeligro,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: nivelColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Fecha de creación
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Creado: ${_formatDate(caso.fechaCreacion)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Indicador de estado (círculo naranja para casos abiertos)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}