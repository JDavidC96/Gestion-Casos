// widgets/case_card.dart
import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../data/risk_data.dart';

class CaseCard extends StatelessWidget {
  final Case caso;
  final VoidCallback onTap;
  final bool mostrarNivelRiesgo;
  final Color? nivelRiesgoColor;
  // Callbacks opcionales para el menú contextual
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  // Si null → no se muestra el menú (inspector sin permisos)
  final bool mostrarMenu;

  const CaseCard({
    super.key,
    required this.caso,
    required this.onTap,
    this.mostrarNivelRiesgo = true,
    this.nivelRiesgoColor,
    this.onEdit,
    this.onDelete,
    this.mostrarMenu = false,
  });

  IconData _getCaseIcon() {
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
    return RiskData.getColorPorCategoria(tipo);
  }

  void _mostrarMenu(BuildContext context) {
    if (!mostrarMenu) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Manija visual
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                caso.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            if (onEdit != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_outlined, color: Colors.blue),
                ),
                title: const Text('Editar caso'),
                subtitle: const Text('Modificar nombre o tipo de riesgo'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                title: const Text(
                  'Eliminar caso',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text('Esta acción no se puede deshacer'),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tipoColor = _getTipoRiesgoColor(caso.tipoRiesgo);
    final nivelColor = nivelRiesgoColor ?? _getnivelPeligroColor(caso.nivelPeligro);
    final caseIcon = _getCaseIcon();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        onLongPress: mostrarMenu ? () => _mostrarMenu(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono principal
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tipoColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(caseIcon, color: tipoColor, size: 24),
              ),
              const SizedBox(width: 16),

              // Contenido del caso
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
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

                    // Descripción
                    Text(
                      caso.descripcionRiesgo,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Subgrupo
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

                    // Chips
                    Row(
                      children: [
                        // Tipo riesgo
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: tipoColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: tipoColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(caseIcon, size: 12, color: tipoColor),
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

                        // Nivel peligro
                        if (mostrarNivelRiesgo &&
                            caso.nivelPeligro.isNotEmpty &&
                            caso.nivelPeligro != 'No aplica')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: nivelColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: nivelColor.withOpacity(0.3)),
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

                    // Fecha
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Creado: ${_formatDate(caso.fechaCreacion)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Indicador de estado + botón de menú
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Indicador naranja de abierto
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
                  // Botón de menú (solo si tiene permisos)
                  if (mostrarMenu) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _mostrarMenu(context),
                      child: Icon(
                        Icons.more_vert,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ),
                  ],
                ],
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