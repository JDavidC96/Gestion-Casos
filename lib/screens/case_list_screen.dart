// lib/screens/case_list_screen.dart (VERSIÓN ACTUALIZADA)
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/case_model.dart';
import '../models/empresa_model.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/case_form_dialog_firebase.dart';
import '../widgets/case_card.dart';
import '../widgets/empty_cases_state.dart';
import '../widgets/closed_cases_header.dart';
import '../widgets/closed_cases_button.dart';

class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  late Empresa _empresa;
  late String _empresaId;
  String? _centroId;
  String? _centroNombre;
  IconData? _empresaIcon;

  // Configuración del grupo
  Map<String, dynamic> _configInterfaz = {};
  bool _mostrarNivelRiesgo = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeEmpresaFromArguments();
    _cargarConfiguracionGrupo();
  }

  void _initializeEmpresaFromArguments() {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    
    if (args != null) {
      _empresaId = args["empresaId"] ?? "empresa_default";
      _empresa = Empresa(
        id: _empresaId,
        nombre: args["empresaNombre"] ?? "Empresa X",
        nit: args["nit"] ?? "",
        icon: args["icon"] ?? Icons.business,
      );
      _centroId = args["centroId"];
      _centroNombre = args["centroNombre"];
      _empresaIcon = args["icon"];
    } else {
      _empresaId = "empresa_default";
      _empresa = Empresa(
        id: "empresa_default",
        nombre: "Empresa X",
        nit: "",
        icon: Icons.business,
      );
      _empresaIcon = Icons.business;
    }
  }

  Future<void> _cargarConfiguracionGrupo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final grupoId = authProvider.grupoId;
      
      if (grupoId != null) {
        final grupoDoc = await FirebaseFirestore.instance
            .collection('grupos')
            .doc(grupoId)
            .get();
        
        if (grupoDoc.exists) {
          final config = grupoDoc.data()?['configInterfaz'] ?? {};
          setState(() {
            _configInterfaz = config;
            _mostrarNivelRiesgo = config['mostrarNivelRiesgo'] ?? true;
          });
        }
      }
    } catch (e) {
      print('Error cargando configuración: $e');
    }
  }

  // Método para obtener el nivel de peligro actualizado
  String _getNivelPeligroActualizado(Map<String, dynamic> data) {
    final estadoAbierto = data['estadoAbierto'] as Map<String, dynamic>?;
    if (estadoAbierto != null && estadoAbierto['nivelPeligro'] != null) {
      return estadoAbierto['nivelPeligro'] as String;
    }
    return data['nivelPeligro'] ?? '';
  }

  void _openAddCaseModal() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Verificar permisos
    if (!authProvider.puedeEditarRecurso(_empresaId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para crear casos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CaseFormDialogFirebase(
        empresa: _empresa,
        empresaId: _empresaId,
        centroId: _centroId,
        centroNombre: _centroNombre,
        grupoId: authProvider.grupoId,
        grupoNombre: authProvider.grupoNombre,
      ),
    );
  }

  void _navegarACasosCerrados(List<Case> casosCerrados) {
    Navigator.pushNamed(
      context,
      '/closedCases',
      arguments: {
        "empresa": _empresa,
        "empresaId": _empresaId,
        "centroId": _centroId,
        "centroNombre": _centroNombre,
        "casosCerrados": casosCerrados,
      },
    );
  }

  void _navegarADetalleCaso(String casoId, Case caso) {
    Navigator.pushNamed(
      context,
      '/caseDetail',
      arguments: {
        "casoId": casoId,
        "caso": caso,
      },
    );
  }

  String _getAppBarTitle() {
    if (_centroNombre != null) {
      return 'Casos - $_centroNombre';
    }
    return 'Casos - ${_empresa.nombre}';
  }

  String _getSubtitle() {
    if (_centroNombre != null) {
      return 'Centro: $_centroNombre';
    }
    return 'Empresa: ${_empresa.nombre}';
  }

  // Método para obtener el color del nivel de riesgo según la configuración
  Color? _getNivelRiesgoColor(Case caso) {
    if (!_mostrarNivelRiesgo) return null;
    
    switch (caso.nivelPeligro) {
      case 'Bajo':
        return Colors.green;
      case 'Medio':
        return Colors.orange;
      case 'Alto':
        return Colors.red[400];
      default:
        return Colors.grey;
    }
  }

  // Método para determinar si mostrar el nivel de riesgo
  bool _debeMostrarNivelRiesgo(Case caso) {
    return _mostrarNivelRiesgo && 
           caso.nivelPeligro.isNotEmpty && 
           caso.nivelPeligro != 'No aplica';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getAppBarTitle()),
            Text(
              _getSubtitle(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
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
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.getCasosPorEmpresaStream(_empresaId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              
              final casosCerrados = snapshot.data!.docs
                  .where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['cerrado'] == true;
                  })
                  .length;

              if (casosCerrados == 0) return const SizedBox.shrink();

              return ClosedCasesButton(
                casosCerradosCount: casosCerrados,
                onPressed: () {
                  final casosCerradosList = snapshot.data!.docs
                      .where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['cerrado'] == true;
                      })
                      .map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Case(
                          id: doc.id,
                          empresaId: data['empresaId'] ?? '',
                          empresaNombre: data['empresaNombre'] ?? '',
                          nombre: data['nombre'] ?? '',
                          tipoRiesgo: data['tipoRiesgo'] ?? '',
                          descripcionRiesgo: data['descripcionRiesgo'] ?? '',
                          nivelPeligro: _getNivelPeligroActualizado(data),
                          fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
                          fechaCierre: (data['fechaCierre'] as Timestamp?)?.toDate(),
                          cerrado: data['cerrado'] ?? false,
                        );
                      })
                      .toList();
                  
                  _navegarACasosCerrados(casosCerradosList);
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getCasosPorEmpresaStream(_empresaId),
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
            return const Center(child: Text('No hay datos'));
          }

          // Filtrar casos por grupo
          final casosFiltrados = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return authProvider.puedeAccederRecurso(data['grupoId']);
          }).toList();

          // Separar casos abiertos y cerrados
          final casosAbiertos = <QueryDocumentSnapshot>[];
          final casosCerrados = <Case>[];

          for (var doc in casosFiltrados) {
            final data = doc.data() as Map<String, dynamic>;
            final cerrado = data['cerrado'] ?? false;

            if (!cerrado) {
              casosAbiertos.add(doc);
            } else {
              casosCerrados.add(Case(
                id: doc.id,
                empresaId: data['empresaId'] ?? '',
                empresaNombre: data['empresaNombre'] ?? '',
                nombre: data['nombre'] ?? '',
                tipoRiesgo: data['tipoRiesgo'] ?? '',
                descripcionRiesgo: data['descripcionRiesgo'] ?? '',
                nivelPeligro: _getNivelPeligroActualizado(data),
                fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
                fechaCierre: (data['fechaCierre'] as Timestamp?)?.toDate(),
                cerrado: true,
              ));
            }
          }

          if (casosAbiertos.isEmpty) {
            return EmptyCasesState(
              empresaIcon: _empresaIcon ?? Icons.business,
              empresaNombre: _empresa.nombre,
              centroNombre: _centroNombre,
              casosCerradosCount: casosCerrados.length,
              onAddCase: _openAddCaseModal,
              onViewClosedCases: () => _navegarACasosCerrados(casosCerrados),
              puedeAgregar: authProvider.puedeEditarRecurso(_empresaId),
            );
          }

          return Column(
            children: [
              if (casosCerrados.isNotEmpty)
                ClosedCasesHeader(
                  casosCerradosCount: casosCerrados.length,
                  onViewClosedCases: () => _navegarACasosCerrados(casosCerrados),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: casosAbiertos.length,
                  itemBuilder: (context, index) {
                    final doc = casosAbiertos[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final casoId = doc.id;

                    final caso = Case(
                      id: casoId,
                      empresaId: data['empresaId'] ?? '',
                      empresaNombre: data['empresaNombre'] ?? '',
                      nombre: data['nombre'] ?? '',
                      tipoRiesgo: data['tipoRiesgo'] ?? '',
                      descripcionRiesgo: data['descripcionRiesgo'] ?? '',
                      nivelPeligro: _getNivelPeligroActualizado(data),
                      fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      cerrado: false,
                    );

                    return CaseCard(
                      caso: caso,
                      onTap: () => _navegarADetalleCaso(casoId, caso),
                      // Pasar configuración al CaseCard
                      mostrarNivelRiesgo: _debeMostrarNivelRiesgo(caso),
                      nivelRiesgoColor: _getNivelRiesgoColor(caso),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: 
          // Solo mostrar FAB si tiene permisos
          authProvider.puedeEditarRecurso(_empresaId)
            ? FloatingActionButton(
                onPressed: _openAddCaseModal,
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                child: const Icon(FontAwesomeIcons.plus),
              )
            : null,
    );
  }
}