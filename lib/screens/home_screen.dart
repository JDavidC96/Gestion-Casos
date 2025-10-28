// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/empresa_model.dart';
import '../providers/case_provider.dart';
import '../widgets/empresa_card.dart';
import '../widgets/empresa_form_dialog.dart';
import '../widgets/empresa_info_dialog.dart';
import '../widgets/empresa_options_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Empresa> _empresas = [
    Empresa(
      id: "empresa_a",
      nombre: "Empresa A",
      nit: "123456789-0",
      icon: Icons.factory,
    ),
    Empresa(
      id: "empresa_b",
      nombre: "Empresa B",
      nit: "987654321-0",
      icon: Icons.business,
    ),
  ];

  void _agregarEmpresa() {
    showDialog(
      context: context,
      builder: (context) => EmpresaFormDialog(
        onSave: (nuevaEmpresa) {
          setState(() {
            _empresas.add(nuevaEmpresa);
          });
        },
      ),
    );
  }

  void _editarEmpresa(int index) {
    showDialog(
      context: context,
      builder: (context) => EmpresaFormDialog(
        empresa: _empresas[index],
        onSave: (empresaEditada) {
          setState(() {
            _empresas[index] = empresaEditada;
          });
        },
      ),
    );
  }

  void _mostrarOpciones(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EmpresaOptionsBottomSheet(
        onViewInfo: () {
          Navigator.pop(context);
          _mostrarInfoEmpresa(index);
        },
        onEdit: () {
          Navigator.pop(context);
          _editarEmpresa(index);
        },
        onDelete: () {
          setState(() {
            _empresas.removeAt(index);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _mostrarInfoEmpresa(int index) {
    final empresa = _empresas[index];
    final caseProvider = Provider.of<CaseProvider>(context, listen: false);
    final cantidadCasos = caseProvider.getCasosPorEmpresa(empresa.id).length;
    final casosAbiertos = caseProvider.cantidadCasosAbiertos(empresa.id);

    showDialog(
      context: context,
      builder: (context) => EmpresaInfoDialog(
        empresa: empresa,
        cantidadCasos: cantidadCasos,
        casosAbiertos: casosAbiertos,
      ),
    );
  }

  void _navegarACentros(Empresa empresa) {
    Navigator.pushNamed(
      context,
      '/centros',
      arguments: {
        "id": empresa.id,
        "nombre": empresa.nombre,
        "nit": empresa.nit,
        "icon": empresa.icon,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final caseProvider = Provider.of<CaseProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Empresas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _empresas.length,
            itemBuilder: (context, index) {
              final empresa = _empresas[index];
              final totalCasos = caseProvider.getCasosPorEmpresa(empresa.id).length;
              final casosAbiertos = caseProvider.cantidadCasosAbiertos(empresa.id);

              return EmpresaCard(
                empresa: empresa,
                totalCasos: totalCasos,
                casosAbiertos: casosAbiertos,
                onTap: () => _navegarACentros(empresa),
                onLongPress: () => _mostrarOpciones(index),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarEmpresa,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}