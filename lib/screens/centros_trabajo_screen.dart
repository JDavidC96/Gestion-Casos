// lib/screens/centros_trabajo_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/empresa_model.dart';
import '../models/centro_trabajo_model.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Verificar permisos
    if (!authProvider.puedeEditarRecurso(_empresaId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para agregar centros de trabajo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CentroTrabajoFormDialogFirebase(
        empresaId: _empresaId,
        empresaNombre: _empresa.nombre,
        grupoId: authProvider.grupoId,
        grupoNombre: authProvider.grupoNombre,
      ),
    );
  }

  void _editarCentro(String centroId, CentroTrabajo centro) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Verificar permisos
    if (!authProvider.puedeEditarRecurso(_empresaId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para editar centros de trabajo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CentroTrabajoFormDialogFirebase(
        empresaId: _empresaId,
        empresaNombre: _empresa.nombre,
        centroId: centroId,
        centro: centro,
        grupoId: authProvider.grupoId,
        grupoNombre: authProvider.grupoNombre,
      ),
    );
  }

  Future<void> _eliminarCentro(String centroId, String nombreCentro) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Verificar permisos
    if (!authProvider.puedeEditarRecurso(_empresaId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para eliminar centros de trabajo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
        "icon": _empresa.icon,
      },
    );
  }

  void _mostrarOpcionesCentro(String centroId, CentroTrabajo centro) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final puedeEditar = authProvider.puedeEditarRecurso(_empresaId);

    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Ver Casos'),
            onTap: () {
              Navigator.pop(context);
              _navegarACasos(centroId, centro);
            },
          ),
          if (puedeEditar) ...[
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
          if (!puedeEditar)
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.grey),
              title: const Text(
                'Sin permisos de edición',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: null,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Centros - ${_empresa.nombre}'),
        actions: [
          // Información de grupo en el appbar
          if (authProvider.grupoNombre != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Text(
                  authProvider.grupoNombre!,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ),
            ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.getCentrosPorEmpresaStream(_empresaId),
            builder: (context, snapshot) {
              final cantidadCentros = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _mostrarInfoEmpresa(cantidadCentros),
                tooltip: 'Información de la empresa',
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
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return EmptyCentrosState(
              empresaIcon: _empresa.icon,
              onAddCentro: _agregarCentroTrabajo,
              puedeAgregar: authProvider.puedeEditarRecurso(_empresaId),
            );
          }

          return _buildCentrosList(snapshot.data!.docs, authProvider);
        },
      ),
      floatingActionButton: 
          // Solo mostrar FAB si tiene permisos
          authProvider.puedeEditarRecurso(_empresaId)
            ? FloatingActionButton(
                onPressed: _agregarCentroTrabajo,
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
    );
  }

  Widget _buildCentrosList(List<QueryDocumentSnapshot> docs, AuthProvider authProvider) {
    // Filtrar centros por grupo si es necesario
    final centrosFiltrados = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return authProvider.puedeAccederRecurso(data['grupoId']);
    }).toList();

    if (centrosFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No tienes acceso a los centros de esta empresa',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Contacta al administrador de tu grupo',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: centrosFiltrados.length,
      itemBuilder: (context, index) {
        final doc = centrosFiltrados[index];
        final data = doc.data() as Map<String, dynamic>;
        final centroId = doc.id;

        // ✅ CAMBIO CRÍTICO AQUÍ - Usar fromMap en lugar de constructor directo
        final centro = CentroTrabajo.fromMap(centroId, data);

        final puedeEditar = authProvider.puedeEditarRecurso(data['grupoId']);

        return CentroTrabajoCard(
          centro: centro,
          onTap: () => _navegarACasos(centroId, centro),
          onLongPress: () => _mostrarOpcionesCentro(centroId, centro),
          puedeEditar: puedeEditar,
        );
      },
    );
  }
}