// lib/screens/home_screen.dart - VERSIÓN COMPLETA ACTUALIZADA
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/empresa_model.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/empresa_card.dart';
import '../widgets/empresa_form_dialog_firebase.dart';
import '../widgets/empresa_info_dialog_firebase.dart';
import '../widgets/empresa_options_bottom_sheet.dart';
import '../utils/icon_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _agregarEmpresa() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => EmpresaFormDialogFirebase(
        onSave: (nuevaEmpresa) {
          setState(() {});
        },
        // Pasar información del grupo automáticamente
        grupoId: authProvider.grupoId,
        grupoNombre: authProvider.grupoNombre,
      ),
    );
  }

  void _editarEmpresa(String empresaId, Empresa empresa) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => EmpresaFormDialogFirebase(
        empresa: empresa,
        empresaId: empresaId,
        onSave: (empresaEditada) {
          setState(() {});
        },
        grupoId: authProvider.grupoId,
        grupoNombre: authProvider.grupoNombre,
      ),
    );
  }

  void _mostrarOpciones(String empresaId, Empresa empresa) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Verificar permisos antes de mostrar opciones
    if (!authProvider.puedeEditarRecurso(empresaId)) {
      return;
    }
    
    showModalBottomSheet(
      context: context,
      builder: (context) => EmpresaOptionsBottomSheet(
        onViewInfo: () {
          Navigator.pop(context);
          _mostrarInfoEmpresa(empresaId, empresa);
        },
        onEdit: () {
          Navigator.pop(context);
          _editarEmpresa(empresaId, empresa);
        },
        onDelete: () async {
          Navigator.pop(context);
          await _confirmarEliminar(empresaId, empresa.nombre);
        },
        puedeEditar: authProvider.puedeEditarRecurso(empresaId),
      ),
    );
  }

  Future<void> _confirmarEliminar(String empresaId, String nombreEmpresa) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Verificar permisos
    if (!authProvider.puedeEditarRecurso(empresaId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para eliminar esta empresa'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar la empresa "$nombreEmpresa"?'),
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
        await FirebaseService.deleteEmpresa(empresaId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empresa eliminada'),
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

  void _mostrarInfoEmpresa(String empresaId, Empresa empresa) async {
    final casosAbiertos = await FirebaseService.contarCasosPorEmpresa(empresaId, cerrados: false);
    final totalCasos = await FirebaseService.contarCasosPorEmpresa(empresaId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => EmpresaInfoDialogFirebase(
        empresa: empresa,
        cantidadCasos: totalCasos,
        casosAbiertos: casosAbiertos,
      ),
    );
  }

  void _navegarACentros(String empresaId, Empresa empresa) {
    Navigator.pushNamed(
      context,
      '/centros',
      arguments: {
        "id": empresaId,
        "nombre": empresa.nombre,
        "nit": empresa.nit,
        "icon": empresa.icon,
      },
    );
  }

  IconData _getIconFromCodePoint(int codePoint) {
    // Mapeo completo de codePoints a IconData constantes
    const iconMap = {
      0xe1d3: Icons.business,
      0xe1db: Icons.store,
      0xe1dc: Icons.store_mall_directory,
      0xe1dd: Icons.shopping_cart,
      0xe1de: Icons.shop,
      0xe1df: Icons.shop_two,
      0xe1e0: Icons.shopping_bag,
      0xe1e1: Icons.shopping_basket,
      0xe1e2: Icons.payment,
      0xe1e3: Icons.credit_card,
      0xe1e4: Icons.account_balance,
      0xe1e5: Icons.account_balance_wallet,
      0xe1e6: Icons.monetization_on,
      0xe1e7: Icons.attach_money,
      0xe1e8: Icons.money_off,
      0xe1e9: Icons.euro_symbol,
      0xe1eb: Icons.currency_bitcoin,
      0xe1ec: Icons.currency_exchange,
      0xe1ed: Icons.currency_franc,
      0xe1ee: Icons.currency_lira,
      0xe1ef: Icons.currency_pound,
      0xe1f0: Icons.currency_ruble,
      0xe1f1: Icons.currency_rupee,
      0xe1f2: Icons.currency_yen,
      0xe1f3: Icons.currency_yuan,
      0xe1f4: Icons.factory,
      0xe1f5: Icons.warehouse,
      0xe1f6: Icons.apartment,
      0xe1f7: Icons.corporate_fare,
      0xe1f8: Icons.local_shipping,
      0xe1f9: Icons.local_hospital,
      0xe1fa: Icons.school,
      0xe1fb: Icons.restaurant,
      0xe1fc: Icons.hotel,
      0xe1fd: Icons.construction,
    };
    
    return iconMap[codePoint] ?? Icons.business;
  }

  IconData _getSafeIcon(Map<String, dynamic> data) {
    try {
      // Primero intenta con el nuevo formato (iconName)
      if (data['iconName'] != null && data['iconName'] is String) {
        return IconUtils.getIconEmpresa(data['iconName']);
      }
      // Si no existe iconName, usa el formato antiguo (codePoint)
      else if (data['icon'] != null) {
        final iconCode = data['icon'] is int ? data['icon'] : Icons.business.codePoint;
        return _getIconFromCodePoint(iconCode);
      }
      // Valor por defecto
      else {
        return Icons.business;
      }
    } catch (e) {
      // En caso de cualquier error, retorna un icono por defecto
      return Icons.business;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Empresas"),
        actions: [
          if (authProvider.userData != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    authProvider.userData!['displayName'] ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (authProvider.grupoNombre != null)
                    Text(
                      authProvider.grupoNombre!,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          // Botón para administración si es super admin o admin
          if (authProvider.isSuperAdmin || authProvider.isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'admin') {
                  if (authProvider.isSuperAdmin) {
                    Navigator.pushNamed(context, '/superAdmin');
                  } else {
                    Navigator.pushNamed(context, '/admin');
                  }
                } else if (value == 'logout') {
                  _cerrarSesion();
                }
              },
              itemBuilder: (context) => [
                if (authProvider.isSuperAdmin || authProvider.isAdmin)
                  const PopupMenuItem(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings),
                        SizedBox(width: 8),
                        Text('Administración'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Cerrar Sesión'),
                    ],
                  ),
                ),
              ],
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
          stream: FirebaseService.getEmpresasPorGrupoStream(authProvider.grupoId),
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
                    const Icon(
                      Icons.business,
                      size: 80,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay empresas registradas',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                    if (authProvider.isSuperAdmin || authProvider.isAdmin) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _agregarEmpresa,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar Primera Empresa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                    if (!authProvider.isSuperAdmin && !authProvider.isAdmin)
                      const SizedBox(height: 16),
                      const Text(
                        'Contacta al administrador para agregar empresas',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final empresaId = doc.id;

                  // Verificar permisos de acceso
                  if (!authProvider.puedeAccederRecurso(data['grupoId'])) {
                    return const SizedBox.shrink(); // No mostrar si no tiene acceso
                  }

                  final empresa = Empresa(
                    id: empresaId,
                    nombre: data['nombre'] ?? '',
                    nit: data['nit'] ?? '',
                    icon: _getSafeIcon(data),
                  );

                  return FutureBuilder<int>(
                    future: Future.wait([
                      FirebaseService.contarCasosPorEmpresa(empresaId),
                      FirebaseService.contarCasosPorEmpresa(empresaId, cerrados: false),
                    ]).then((results) => results[1]), // casos abiertos
                    builder: (context, casosSnapshot) {
                      final casosAbiertos = casosSnapshot.data ?? 0;
                      
                      return FutureBuilder<int>(
                        future: FirebaseService.contarCasosPorEmpresa(empresaId),
                        builder: (context, totalSnapshot) {
                          final totalCasos = totalSnapshot.data ?? 0;

                          return EmpresaCard(
                            empresa: empresa,
                            totalCasos: totalCasos,
                            casosAbiertos: casosAbiertos,
                            onTap: () => _navegarACentros(empresaId, empresa),
                            onLongPress: () => _mostrarOpciones(empresaId, empresa),
                            puedeEditar: authProvider.puedeEditarRecurso(data['grupoId']),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: 
          // Solo mostrar FAB si tiene permisos
          authProvider.isSuperAdmin || authProvider.isAdmin 
            ? FloatingActionButton(
                onPressed: _agregarEmpresa,
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
    );
  }

  Future<void> _cerrarSesion() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}