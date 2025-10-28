// screens/centros_trabajo_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/empresa_model.dart';
import '../models/centro_trabajo_model.dart';
import '../providers/centro_trabajo_provider.dart';
import '../widgets/centro_trabajo_form_dialog.dart';
import '../widgets/empresa_info_dialog_centros.dart';
import '../widgets/centro_trabajo_card.dart';
import '../widgets/empty_centros_state.dart';

class CentrosTrabajoScreen extends StatefulWidget {
  const CentrosTrabajoScreen({super.key});

  @override
  State<CentrosTrabajoScreen> createState() => _CentrosTrabajoScreenState();
}

class _CentrosTrabajoScreenState extends State<CentrosTrabajoScreen> {
  late Empresa _empresa;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeEmpresaFromArguments();
  }

  void _initializeEmpresaFromArguments() {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    
    if (args != null) {
      _empresa = Empresa(
        id: args["id"] ?? "empresa_default",
        nombre: args["nombre"] ?? "Empresa X",
        nit: args["nit"] ?? "",
        icon: args["icon"] ?? Icons.business,
      );
    } else {
      _empresa = Empresa(
        id: "empresa_default",
        nombre: "Empresa X",
        nit: "",
        icon: Icons.business,
      );
    }
  }

  void _agregarCentroTrabajo() {
    showDialog(
      context: context,
      builder: (context) => CentroTrabajoFormDialog(
        empresaId: _empresa.id,
      ),
    );
  }

  void _mostrarInfoEmpresa(int cantidadCentros) {
    showDialog(
      context: context,
      builder: (context) => EmpresaInfoDialogCentros(
        empresa: _empresa,
        cantidadCentros: cantidadCentros,
      ),
    );
  }

  void _navegarACasos(CentroTrabajo centro) {
    Navigator.pushNamed(
      context,
      '/cases',
      arguments: {
        "empresaId": _empresa.id,
        "empresaNombre": _empresa.nombre,
        "centroId": centro.id,
        "centroNombre": centro.nombre,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final centroProvider = Provider.of<CentroTrabajoProvider>(context);
    final centros = centroProvider.getCentrosPorEmpresa(_empresa.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Centros - ${_empresa.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _mostrarInfoEmpresa(centros.length),
          ),
        ],
      ),
      body: centros.isEmpty
          ? EmptyCentrosState(
              empresaIcon: _empresa.icon,
              onAddCentro: _agregarCentroTrabajo,
            )
          : _buildCentrosList(centros),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarCentroTrabajo,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCentrosList(List<CentroTrabajo> centros) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: centros.length,
      itemBuilder: (context, index) {
        final centro = centros[index];
        return CentroTrabajoCard(
          centro: centro,
          onTap: () => _navegarACasos(centro),
        );
      },
    );
  }
}