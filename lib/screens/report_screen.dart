import 'package:flutter/material.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reporte de Casos")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.table_chart,
                        size: 80, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text(
                      "Reporte en Excel",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Aquí podrás generar el archivo Excel con el listado de casos, incluyendo fotos de apertura y cierre.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Botón grande de exportar
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Exportar Excel no implementado")),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text(
                "Exportar a Excel",
                style: TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 20),

            // Placeholder para resumen
            const ListTile(
              leading: Icon(Icons.business, color: Colors.blue),
              title: Text("Empresa A"),
              subtitle: Text("Total de casos: 3"),
            ),
          ],
        ),
      ),
    );
  }
}
