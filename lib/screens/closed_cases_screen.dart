// closed_cases_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/empresa_model.dart';
import '../providers/case_provider.dart';

class ClosedCasesScreen extends StatelessWidget {
  const ClosedCasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final Empresa empresa = args?["empresa"] ?? Empresa(
      id: "empresa_default",
      nombre: "Empresa X",
      nit: "",
      icon: Icons.business,
    );

    final caseProvider = Provider.of<CaseProvider>(context);
    final casosCerrados = caseProvider.getCasosPorEmpresa(empresa.id)
        .where((caso) => caso.cerrado)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Casos Cerrados - ${empresa.nombre}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: casosCerrados.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.archive,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay casos cerrados para ${empresa.nombre}',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver a Casos Abiertos'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: casosCerrados.length,
              itemBuilder: (context, index) {
                final caso = casosCerrados[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  color: Colors.green.withOpacity(0.05),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
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
                    title: Text(
                      caso.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(caso.descripcionRiesgo),
                        const SizedBox(height: 4),
                        Text(
                          caso.fechaCierre != null 
                              ? "Cerrado: ${caso.fechaCierre!.toString().substring(0, 16)}"
                              : "Cerrado: Fecha no disponible",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/caseDetail',
                        arguments: {
                          "caso": caso,
                        },
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}