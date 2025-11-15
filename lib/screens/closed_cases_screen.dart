// lib/screens/closed_cases_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/empresa_model.dart';
import '../models/case_model.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../data/risk_data.dart';

class ClosedCasesScreen extends StatelessWidget {
  const ClosedCasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Obtener datos de la empresa
    final Empresa empresa = args?["empresa"] ?? Empresa(
      id: args?["empresaId"] ?? "empresa_default",
      nombre: "Empresa X",
      nit: "",
      icon: Icons.business,
    );
    
    final String empresaId = args?["empresaId"] ?? empresa.id;
    final String? centroNombre = args?["centroNombre"];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Casos Cerrados'),
            Text(
              centroNombre ?? empresa.nombre,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // Información del grupo
          if (authProvider.grupoNombre != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Text(
                  authProvider.grupoNombre!,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getCasosPorEmpresaStream(empresaId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData) {
            return _buildEmptyState(context, empresa.nombre, centroNombre);
          }

          // Filtrar casos por grupo y solo casos cerrados
          final casosCerrados = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final esCerrado = data['cerrado'] == true;
            final tieneAcceso = authProvider.puedeAccederRecurso(data['grupoId']);
            return esCerrado && tieneAcceso;
          }).toList();

          if (casosCerrados.isEmpty) {
            return _buildEmptyState(context, empresa.nombre, centroNombre);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: casosCerrados.length,
            itemBuilder: (context, index) {
              final doc = casosCerrados[index];
              final data = doc.data() as Map<String, dynamic>;
              final casoId = doc.id;

              // Construir el caso
              final caso = Case(
                id: casoId,
                empresaId: data['empresaId'] ?? '',
                empresaNombre: data['empresaNombre'] ?? '',
                nombre: data['nombre'] ?? '',
                tipoRiesgo: data['tipoRiesgo'] ?? '',
                descripcionRiesgo: data['descripcionRiesgo'] ?? '',
                nivelPeligro: data['nivelPeligro'] ?? '',
                fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
                fechaCierre: (data['fechaCierre'] as Timestamp?)?.toDate(),
                cerrado: true,
              );

              return _buildCaseCard(context, caso, casoId);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String empresaNombre, String? centroNombre) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.archive,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              'No hay casos cerrados',
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
              'Los casos que se cierren aparecerán aquí para su consulta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver a Casos Abiertos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseCard(BuildContext context, Case caso, String casoId) {
    final tipoColor = _getTipoRiesgoColor(caso.tipoRiesgo);
    final nivelColor = _getnivelPeligroColor(caso.nivelPeligro);
    final caseIcon = _getCaseIcon(caso.tipoRiesgo);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      color: Colors.green.withOpacity(0.02),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.green.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/caseDetail',
            arguments: {
              "casoId": casoId,
              "caso": caso,
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono principal con check de cerrado
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Contenido
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                        
                        // Nivel de peligro
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
                    
                    // Fechas
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        if (caso.fechaCierre != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 12,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Cerrado: ${_formatDate(caso.fechaCierre!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Indicador de tiempo transcurrido desde el cierre
              if (caso.fechaCierre != null)
                _buildTimeSinceClose(caso.fechaCierre!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSinceClose(DateTime fechaCierre) {
    final now = DateTime.now();
    final difference = now.difference(fechaCierre);
    
    String text;
    Color color;
    
    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      text = '${months}m';
      color = Colors.green;
    } else if (difference.inDays > 0) {
      text = '${difference.inDays}d';
      color = Colors.green[600]!;
    } else if (difference.inHours > 0) {
      text = '${difference.inHours}h';
      color = Colors.green[400]!;
    } else {
      text = '${difference.inMinutes}m';
      color = Colors.green[300]!;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Métodos auxiliares para colores e iconos (consistentes con case_card)
  IconData _getCaseIcon(String tipoRiesgo) {
    return tiposDePeligro.firstWhere(
      (item) => item["tipo"] == tipoRiesgo,
      orElse: () => {"icon": Icons.help},
    )["icon"];
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
    switch (tipo) {
      case 'Físico':
        return Colors.blue;
      case 'Químico':
        return Colors.orange;
      case 'Biológico':
        return Colors.green;
      case 'Ergonómico':
        return Colors.purple;
      case 'Psicosocial':
        return Colors.pink;
      case 'Mecánico':
        return Colors.brown;
      case 'Eléctrico':
        return Colors.yellow[700]!;
      case 'Incendio':
        return Colors.red;
      case 'Caídas':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}