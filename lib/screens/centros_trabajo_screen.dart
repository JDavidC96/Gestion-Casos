// lib/screens/centros_trabajo_screen.dart - VERSIÓN CORREGIDA
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/empresa_model.dart';
import '../models/centro_trabajo_model.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/centro_trabajo_card.dart';
import '../widgets/centro_trabajo_form_dialog_firebase.dart';

class CentrosTrabajoScreen extends StatefulWidget {
  const CentrosTrabajoScreen({super.key});

  @override
  State<CentrosTrabajoScreen> createState() => _CentrosTrabajoScreenState();
}

class _CentrosTrabajoScreenState extends State<CentrosTrabajoScreen> {
  Empresa? _empresa; // Cambiar a nullable
  String? _empresaId; // Cambiar a nullable
  bool _isLoading = true;

  // Mapa para almacenar el conteo de casos por centro
  final Map<String, int> _casosAbiertosPorCentro = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmpresaFromArguments();
    });
  }

  void _loadEmpresaFromArguments() {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    
    if (args != null) {
      setState(() {
        _empresaId = args["empresaId"] ?? "empresa_default";
        _empresa = Empresa(
          id: _empresaId!,
          nombre: args["empresaNombre"] ?? "Empresa X",
          nit: args["nit"] ?? "",
          icon: args["icon"] ?? Icons.business,
        );
      });
      _cargarCasosAbiertos();
    } else {
      setState(() {
        _empresaId = "empresa_default";
        _empresa = Empresa(
          id: "empresa_default",
          nombre: "Empresa X",
          nit: "",
          icon: Icons.business,
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarCasosAbiertos() async {
    try {      
      // Obtener todos los casos de la empresa
      final casosSnapshot = await FirebaseFirestore.instance
          .collection('casos')
          .where('empresaId', isEqualTo: _empresaId)
          .where('cerrado', isEqualTo: false)
          .get();

      // Contar casos por centro de trabajo
      final casosPorCentro = <String, int>{};
      
      for (var doc in casosSnapshot.docs) {
        final data = doc.data();
        final centroId = data['centroId'] as String?;
        
        if (centroId != null) {
          casosPorCentro[centroId] = (casosPorCentro[centroId] ?? 0) + 1;
        }
      }

      setState(() {
        _casosAbiertosPorCentro.clear();
        _casosAbiertosPorCentro.addAll(casosPorCentro);
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando casos abiertos: $e');
      setState(() => _isLoading = false);
    }
  }

  void _navegarACasosDelCentro(String centroId, String centroNombre) {
    Navigator.pushNamed(
      context,
      '/cases',
      arguments: {
        "empresaId": _empresaId,
        "empresaNombre": _empresa?.nombre ?? "Empresa X",
        "centroId": centroId,
        "centroNombre": centroNombre,
        "icon": _empresa?.icon ?? Icons.business,
        "nit": _empresa?.nit ?? "",
      },
    );
  }

  void _mostrarFormularioCentro([String? centroId, Map<String, dynamic>? centroData]) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => CentroTrabajoFormDialogFirebase(
        empresaId: _empresaId ?? "empresa_default",
        empresaNombre: _empresa?.nombre ?? "Empresa X",
        centroId: centroId,
        centro: centroData != null ? CentroTrabajo.fromMap(centroId ?? '', centroData) : null,
        grupoId: authProvider.grupoId,
        grupoNombre: authProvider.grupoNombre,
      ),
    ).then((_) {
      // Recargar datos después de agregar/editar centro
      if (mounted) {
        _cargarCasosAbiertos(); // Recargar casos abiertos
      }
    });
  }

  void _mostrarMenuOpciones(BuildContext context, String centroId, String centroNombre, Map<String, dynamic> centroData) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.puedeEditarRecurso(_empresaId ?? "empresa_default")) {
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar Centro'),
            onTap: () {
              Navigator.pop(context);
              _mostrarFormularioCentro(centroId, centroData);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Eliminar Centro', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmarEliminarCentro(centroId, centroNombre);
            },
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    return 'Centros - ${_empresa?.nombre ?? "Cargando..."}';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Mostrar loading si aún está cargando o si la empresa no se ha inicializado
    if (_isLoading || _empresa == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_getAppBarTitle()),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getAppBarTitle()),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseService.getCasosPorEmpresaStream(_empresaId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text(
                    'Cargando casos...',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  );
                }

                final casosAbiertos = snapshot.data!.docs
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['cerrado'] == false && 
                             authProvider.puedeAccederRecurso(data['grupoId']);
                    })
                    .length;

                return Text(
                  '$casosAbiertos casos abiertos en la empresa',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                );
              },
            ),
          ],
        ),
        actions: [
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseService.getCentrosPorEmpresaStream(_empresaId!),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
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
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_empresa!.icon, size: 80, color: Colors.white70),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay centros de trabajo',
                      style: TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Empresa: ${_empresa!.nombre}',
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _mostrarFormularioCentro(),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Primer Centro'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            final centros = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: centros.length,
              itemBuilder: (context, index) {
                final doc = centros[index];
                final data = doc.data() as Map<String, dynamic>;
                final centroId = doc.id;
                
                // Crear el CentroTrabajo con todos los parámetros requeridos
                final centro = CentroTrabajo(
                  id: centroId,
                  empresaId: data['empresaId'] ?? _empresaId!,
                  nombre: data['nombre'] ?? 'Sin nombre',
                  direccion: data['direccion'] ?? 'Sin dirección',
                  tipo: data['tipo'] ?? 'General',
                  grupoId: data['grupoId'] ?? authProvider.grupoId ?? '',
                  grupoNombre: data['grupoNombre'] ?? authProvider.grupoNombre ?? '',
                );

                // Obtener número de casos abiertos para este centro
                final casosAbiertos = _casosAbiertosPorCentro[centroId] ?? 0;

                return CentroTrabajoCard(
                  centro: centro,
                  casosAbiertos: casosAbiertos,
                  onTap: () => _navegarACasosDelCentro(centroId, centro.nombre),
                  onLongPress: authProvider.puedeEditarRecurso(_empresaId!)
                      ? () => _mostrarMenuOpciones(context, centroId, centro.nombre, data)
                      : () {},
                  puedeEditar: authProvider.puedeEditarRecurso(_empresaId!),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Provider.of<AuthProvider>(context).puedeEditarRecurso(_empresaId!)
          ? FloatingActionButton(
              onPressed: () => _mostrarFormularioCentro(),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _confirmarEliminarCentro(String centroId, String centroNombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar el centro "$centroNombre"?'),
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
              content: Text('Centro eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          // Recargar casos abiertos después de eliminar
          _cargarCasosAbiertos();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar centro: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}