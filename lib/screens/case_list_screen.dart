// lib/screens/case_list_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/case_model.dart';
import '../models/empresa_model.dart';
import '../services/firebase_service.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeEmpresaFromArguments();
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
    } else {
      _empresaId = "empresa_default";
      _empresa = Empresa(
        id: "empresa_default",
        nombre: "Empresa X",
        nit: "",
        icon: Icons.business,
      );
    }
  }

  void _openAddCaseModal() {
    showDialog(
      context: context,
      builder: (context) => CaseFormDialogFirebase(
        empresa: _empresa,
        empresaId: _empresaId,
        centroId: _centroId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Casos Abiertos - ${_empresa.nombre}'),
        actions: [
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
                          nivelRiesgo: data['nivelRiesgo'] ?? '',
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

          // Separar casos abiertos y cerrados
          final casosAbiertos = <QueryDocumentSnapshot>[];
          final casosCerrados = <Case>[];

          for (var doc in snapshot.data!.docs) {
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
                nivelRiesgo: data['nivelRiesgo'] ?? '',
                fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
                fechaCierre: (data['fechaCierre'] as Timestamp?)?.toDate(),
                cerrado: true,
              ));
            }
          }

          if (casosAbiertos.isEmpty) {
            return EmptyCasesState(
              empresaIcon: _empresa.icon,
              empresaNombre: _empresa.nombre,
              casosCerradosCount: casosCerrados.length,
              onAddCase: _openAddCaseModal,
              onViewClosedCases: () => _navegarACasosCerrados(casosCerrados),
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
                      nivelRiesgo: data['nivelRiesgo'] ?? '',
                      fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      cerrado: false,
                    );

                    return CaseCard(
                      caso: caso,
                      onTap: () => _navegarADetalleCaso(casoId, caso),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddCaseModal,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(FontAwesomeIcons.plus),
      ),
    );
  }
}