// lib/widgets/assign_empresas_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../providers/empresas_provider.dart';

class AssignEmpresasDialog extends StatefulWidget {
  final String userId;
  final String userDisplayName;
  final List<String> empresasActuales;
  final EmpresasProvider empresasProvider; // Recibir el provider

  const AssignEmpresasDialog({
    super.key,
    required this.userId,
    required this.userDisplayName,
    required this.empresasActuales,
    required this.empresasProvider, // Añadir parámetro
  });

  @override
  State<AssignEmpresasDialog> createState() => _AssignEmpresasDialogState();
}

class _AssignEmpresasDialogState extends State<AssignEmpresasDialog> {
  final List<String> _empresasSeleccionadas = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _empresasDisponibles = [];

  @override
  void initState() {
    super.initState();
    _empresasSeleccionadas.addAll(widget.empresasActuales);
    _loadEmpresasDisponibles();
  }

  Future<void> _loadEmpresasDisponibles() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final empresasQuery = await FirebaseService.getEmpresasPorGrupo(authProvider.grupoId);
      
      setState(() {
        _empresasDisponibles = empresasQuery.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return {
            'id': doc.id,
            'nombre': data['nombre'] ?? 'Sin nombre',
            'nit': data['nit'] ?? '',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando empresas: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleEmpresa(String empresaId) {
    setState(() {
      if (_empresasSeleccionadas.contains(empresaId)) {
        _empresasSeleccionadas.remove(empresaId);
      } else {
        _empresasSeleccionadas.add(empresaId);
      }
    });
  }

  Future<void> _guardarAsignaciones() async {
    try {
      await UserService.assignEmpresasToUser(widget.userId, _empresasSeleccionadas);
      
      // Usar el provider que se pasó como parámetro
      widget.empresasProvider.updateEmpresasUsuario(widget.userId, _empresasSeleccionadas);
      
      if (mounted) {
        Navigator.pop(context, true); // Retornar true indicando éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Empresas asignadas correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, false); // Retornar false indicando error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al asignar empresas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Asignar Empresas a ${widget.userDisplayName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona las empresas que este inspector podrá gestionar:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _empresasDisponibles.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.business, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No hay empresas disponibles',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  'Agrega empresas primero en la pantalla principal',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _empresasDisponibles.length,
                            itemBuilder: (context, index) {
                              final empresa = _empresasDisponibles[index];
                              final isSelected = _empresasSeleccionadas.contains(empresa['id']);
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: CheckboxListTile(
                                  title: Text(empresa['nombre']),
                                  subtitle: Text('NIT: ${empresa['nit']}'),
                                  value: isSelected,
                                  onChanged: (value) => _toggleEmpresa(empresa['id']),
                                  secondary: const Icon(Icons.business),
                                ),
                              );
                            },
                          ),
              ),
              
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _guardarAsignaciones,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Guardar Asignaciones'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}