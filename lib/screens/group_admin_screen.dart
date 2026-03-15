// lib/screens/group_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/admin_controller.dart';
import '../providers/empresas_provider.dart';
import '../widgets/logo_section.dart';
import '../widgets/users_list_section.dart';
import '../widgets/user_form_dialog.dart';

/// Pantalla de administración de un grupo específico, para uso del SuperAdmin.
/// Replica la misma interfaz que AdminScreen pero para cualquier grupo,
/// sin depender del AuthProvider.
///
/// Recibe los argumentos vía Navigator:
///   {
///     'groupId':   String,
///     'groupName': String?,
///   }
class GroupAdminScreen extends StatefulWidget {
  const GroupAdminScreen({super.key});

  @override
  State<GroupAdminScreen> createState() => _GroupAdminScreenState();
}

class _GroupAdminScreenState extends State<GroupAdminScreen> {
  late final String _groupId;
  late final String? _groupName;
  late final AdminController _adminController;
  late final EmpresasProvider _empresasProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _groupId = args['groupId'] as String;
    _groupName = args['groupName'] as String?;
    _adminController = AdminController();
    _empresasProvider = EmpresasProvider();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adminController.loadLogoForGroup(_groupId);
    });
  }

  @override
  void dispose() {
    _adminController.dispose();
    _empresasProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _adminController),
        ChangeNotifierProvider.value(value: _empresasProvider),
      ],
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildBody(),
        floatingActionButton: _buildFABs(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(_groupName ?? 'Administración de Grupo'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _configurarInterfaz,
          tooltip: 'Configurar Interfaz',
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                LogoSection(
                  grupoId: _groupId,
                  grupoNombre: _groupName,
                  onChangeLogo: _cambiarLogo,
                  onDeleteLogo: _eliminarLogo,
                  onConfigureInterface: _configurarInterfaz,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Lista de usuarios — ocupa el espacio restante
          SliverFillRemaining(
            child: UsersListSection(
              grupoId: _groupId,
              grupoNombre: _groupName,
              onAddUser: _agregarInspector,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFABs() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: _configurarInterfaz,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          mini: true,
          heroTag: 'fab_config',
          tooltip: 'Configurar Interfaz',
          child: const Icon(Icons.settings),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: _cambiarLogo,
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          mini: true,
          heroTag: 'fab_logo',
          tooltip: 'Cambiar Logo',
          child: const Icon(Icons.image),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: _agregarInspector,
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          heroTag: 'fab_add',
          tooltip: 'Agregar Inspector',
          child: const Icon(Icons.person_add),
        ),
      ],
    );
  }

  void _cambiarLogo() {
    _adminController.changeLogoForGroup(context, _groupId);
  }

  void _eliminarLogo() {
    _adminController.deleteLogoForGroup(context, _groupId);
  }

  void _configurarInterfaz() {
    Navigator.pushNamed(
      context,
      '/interface_config',
      arguments: {
        'groupId': _groupId,
        'groupData': {'nombre': _groupName},
      },
    );
  }

  void _agregarInspector() {
    showDialog(
      context: context,
      builder: (_) => UserFormDialog(
        onSave: (userData) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inspector agregado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        },
        isSuperAdmin: true,
        grupoId: _groupId,
        grupoNombre: _groupName,
      ),
    );
  }
}