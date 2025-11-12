// lib/screens/home_screen.dart
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
    showDialog(
      context: context,
      builder: (context) => EmpresaFormDialogFirebase(
        onSave: (nuevaEmpresa) {
          setState(() {});
        },
      ),
    );
  }

  void _editarEmpresa(String empresaId, Empresa empresa) {
    showDialog(
      context: context,
      builder: (context) => EmpresaFormDialogFirebase(
        empresa: empresa,
        empresaId: empresaId,
        onSave: (empresaEditada) {
          setState(() {});
        },
      ),
    );
  }

  void _mostrarOpciones(String empresaId, Empresa empresa) {
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
      ),
    );
  }

  Future<void> _confirmarEliminar(String empresaId, String nombreEmpresa) async {
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
              child: Center(
                child: Text(
                  authProvider.userData!['displayName'] ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseService.getEmpresasStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarEmpresa,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}