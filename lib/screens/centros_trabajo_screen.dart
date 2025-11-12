// lib/screens/centros_trabajo_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/empresa_model.dart';
import '../models/centro_trabajo_model.dart';
import '../services/firebase_service.dart';
import '../widgets/centro_trabajo_form_dialog_firebase.dart';
import '../widgets/empresa_info_dialog_centros_firebase.dart';
import '../widgets/centro_trabajo_card.dart';
import '../widgets/empty_centros_state.dart';

class CentrosTrabajoScreen extends StatefulWidget {
  const CentrosTrabajoScreen({super.key});

  @override
  State<CentrosTrabajoScreen> createState() => _CentrosTrabajoScreenState();
}

class _CentrosTrabajoScreenState extends State<CentrosTrabajoScreen> {
  late Empresa _empresa;
  late String _empresaId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeEmpresaFromArguments();
  }

  void _initializeEmpresaFromArguments() {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    
    if (args != null) {
      _empresaId = args["id"] ?? "empresa_default";
      _empresa = Empresa(
        id: _empresaId,
        nombre: args["nombre"] ?? "Empresa X",
        nit: args["nit"] ?? "",
        icon: args["icon"] ?? Icons.business,
      );
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

  void _agregarCentroTrabajo() {
    showDialog(
      context: context,
      builder: (context) => CentroTrabajoFormDialogFirebase(
        empresaId: _empresaId,
      ),
    );
  }

  void _editarCentro(String centroId, CentroTrabajo centro) {
    showDialog(
      context: context,
      builder: (context) => CentroTrabajoFormDialogFirebase(
        empresaId: _empresaId,
        centroId: centroId,
        centro: centro,
      ),
    );
  }

  Future<void> _eliminarCentro(String centroId, String nombreCentro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar el centro "$nombreCentro"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await FirebaseService.deleteCentroTrabajo(centroId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Centro eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _mostrarInfoEmpresa(int cantidadCentros) {
    showDialog(
      context: context,
      builder: (context) => EmpresaInfoDialogCentrosFirebase(
        empresa: _empresa,
        cantidadCentros: cantidadCentros,
      ),
    );
  }

  void _navegarACasos(String centroId, CentroTrabajo centro) {
    Navigator.pushNamed(
      context,
      '/cases',
      arguments: {
        "empresaId": _empresaId,
        "empresaNombre": _empresa.nombre,
        "centroId": centroId,
        "centroNombre": centro.nombre,
      },
    );
  }

  void _mostrarOpcionesCentro(String centroId, CentroTrabajo centro) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar'),
            onTap: () {
              Navigator.pop(context);
              _editarCentro(centroId, centro);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Eliminar'),
            onTap: () {
              Navigator.pop(context);
              _eliminarCentro(centroId, centro.nombre);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Centros - ${_empresa.nombre}'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.getCentrosPorEmpresaStream(_empresaId),
            builder: (context, snapshot) {
              final cantidadCentros = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _mostrarInfoEmpresa(cantidadCentros),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getCentrosPorEmpresaStream(_empresaId),
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return EmptyCentrosState(
              empresaIcon: _empresa.icon,
              onAddCentro: _agregarCentroTrabajo,
            );
          }

          return _buildCentrosList(snapshot.data!.docs);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarCentroTrabajo,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCentrosList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final centroId = doc.id;

        final centro = CentroTrabajo(
          id: centroId,
          empresaId: data['empresaId'] ?? '',
          nombre: data['nombre'] ?? '',
          direccion: data['direccion'] ?? '',
          tipo: data['tipo'] ?? '',
        );

        return CentroTrabajoCard(
          centro: centro,
          onTap: () => _navegarACasos(centroId, centro),
          onLongPress: () => _mostrarOpcionesCentro(centroId, centro),
        );
      },
    );
  }
}