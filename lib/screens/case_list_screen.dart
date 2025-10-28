// screens/case_list_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/case_model.dart';
import '../models/empresa_model.dart';
import '../providers/case_provider.dart';
import '../widgets/case_form_dialog.dart';
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
      _empresa = Empresa(
        id: args["empresaId"] ?? args["id"] ?? "empresa_default",
        nombre: args["empresaNombre"] ?? args["nombre"] ?? "Empresa X",
        nit: args["nit"] ?? "",
        icon: args["icon"] ?? Icons.business,
      );
      _centroId = args["centroId"];
      _centroNombre = args["centroNombre"];
    } else {
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
      builder: (context) => CaseFormDialog(empresa: _empresa),
    );
  }

  void _navegarACasosCerrados() {
    Navigator.pushNamed(
      context,
      '/closedCases',
      arguments: {
        "empresa": _empresa,
        "centroId": _centroId,
        "centroNombre": _centroNombre,
      },
    );
  }

  void _navegarADetalleCaso(Case caso) {
    Navigator.pushNamed(
      context,
      '/caseDetail',
      arguments: {
        "caso": caso,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final caseProvider = Provider.of<CaseProvider>(context);
    final casosAbiertos = caseProvider.getCasosPorEmpresa(_empresa.id)
        .where((caso) => !caso.cerrado)
        .toList();

    final casosCerrados = caseProvider.getCasosPorEmpresa(_empresa.id)
        .where((caso) => caso.cerrado)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Casos Abiertos - ${_empresa.nombre}'),
        actions: [
          if (casosCerrados.isNotEmpty)
            ClosedCasesButton(
              casosCerradosCount: casosCerrados.length,
              onPressed: _navegarACasosCerrados,
            ),
        ],
      ),
      body: casosAbiertos.isEmpty
          ? EmptyCasesState(
              empresaIcon: _empresa.icon,
              empresaNombre: _empresa.nombre,
              casosCerradosCount: casosCerrados.length,
              onAddCase: _openAddCaseModal,
              onViewClosedCases: _navegarACasosCerrados,
            )
          : Column(
              children: [
                if (casosCerrados.isNotEmpty)
                  ClosedCasesHeader(
                    casosCerradosCount: casosCerrados.length,
                    onViewClosedCases: _navegarACasosCerrados,
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: casosAbiertos.length,
                    itemBuilder: (context, index) {
                      final caso = casosAbiertos[index];
                      return CaseCard(
                        caso: caso,
                        onTap: () => _navegarADetalleCaso(caso),
                      );
                    },
                  ),
                ),
              ],
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