// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/empresas_provider.dart'; // Añadir import
import '../controllers/admin_controller.dart';
import '../widgets/user_form_dialog.dart';
import '../widgets/logo_section.dart';
import '../widgets/users_list_section.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late AdminController _adminController;
  late EmpresasProvider _empresasProvider; // Añadir provider

  @override
  void initState() {
    super.initState();
    _adminController = AdminController();
    _empresasProvider = EmpresasProvider(); // Inicializar provider
  }

  @override
Widget build(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: _adminController),
      ChangeNotifierProvider.value(value: _empresasProvider),
    ],
    child: _AdminScreenContent(authProvider: authProvider),
  );
}

}

class _AdminScreenContent extends StatefulWidget {
  final AuthProvider authProvider;

  const _AdminScreenContent({required this.authProvider});

  @override
  State<_AdminScreenContent> createState() => _AdminScreenContentState();
}

class _AdminScreenContentState extends State<_AdminScreenContent> {
  @override
  void initState() {
    super.initState();
    // Inicializar el controller después de que el Provider esté disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<AdminController>();
      controller.initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminController = context.watch<AdminController>();

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(adminController),
      floatingActionButton: _buildFloatingActionButtons(adminController),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: _buildAppBarTitle(),
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
        if (widget.authProvider.isAdmin) // Solo mostrar para admins
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _configurarInterfaz,
            tooltip: 'Configurar Interfaz',
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.authProvider.userData!['displayName'] ?? '',
                style: const TextStyle(fontSize: 14),
              ),
              if (widget.authProvider.grupoNombre != null)
                Text(
                  widget.authProvider.grupoNombre!,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              Text(
                _getRoleDisplayName(),
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
          tooltip: 'Ir al Inicio',
        ),
      ],
    );
  }

  Widget _buildAppBarTitle() {
    if (widget.authProvider.isAdmin) {
      return const Text("Administración de Grupo");
    } else if (widget.authProvider.isSuperInspector) {
      return const Text("Gestión de Empresas");
    } else {
      return const Text("Panel de Inspector");
    }
  }

  String _getRoleDisplayName() {
    if (widget.authProvider.isAdmin) return 'Admin';
    if (widget.authProvider.isSuperInspector) return 'Super Inspector';
    return 'Inspector';
  }

  Widget _buildBody(AdminController adminController) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: widget.authProvider.grupoId == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _buildContent(adminController),
    );
  }

  Widget _buildContent(AdminController adminController) {
    // Mostrar diferentes contenidos según el rol
    if (widget.authProvider.isAdmin) {
      return _buildAdminContent(adminController);
    } else {
      return _buildInspectorContent();
    }
  }

  // Contenido para Admin de Grupo
  Widget _buildAdminContent(AdminController adminController) {
    return Column(
      children: [
        // Sección del logo (solo para admin de grupo)
        LogoSection(
          grupoId: widget.authProvider.grupoId,
          grupoNombre: widget.authProvider.grupoNombre,
          onChangeLogo: () => _cambiarLogo(context),
          onDeleteLogo: () => _eliminarLogo(context),
          onConfigureInterface: _configurarInterfaz,
        ),
        const SizedBox(height: 16),
        // Lista de inspectores del grupo
        Expanded(
          child: UsersListSection(
            grupoId: widget.authProvider.grupoId!,
            grupoNombre: widget.authProvider.grupoNombre,
            onAddUser: _agregarInspector,
          ),
        ),
      ],
    );
  }

  // Contenido para Inspectores (Super Inspector e Inspector normal)
  Widget _buildInspectorContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 80, color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Panel de Inspector',
            style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Accede a las empresas desde la pantalla principal',
            style: TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            '👆 Ve a "Empresas" en el menú inferior',
            style: TextStyle(fontSize: 14, color: Colors.white60),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons(AdminController adminController) {
    // Mostrar diferentes FABs según el rol
    if (widget.authProvider.isAdmin) {
      return _buildAdminFABs(adminController);
    } else {
      return const SizedBox.shrink(); // No mostrar FABs para inspectores
    }
  }

  Widget _buildAdminFABs(AdminController adminController) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Botón para configurar interfaz
        FloatingActionButton(
          onPressed: _configurarInterfaz,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          mini: true,
          child: const Icon(Icons.settings),
          tooltip: 'Configurar Interfaz',
        ),
        const SizedBox(height: 16),
        // Botón para cambiar logo
        FloatingActionButton(
          onPressed: () => _cambiarLogo(context),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          mini: true,
          child: const Icon(Icons.image),
          tooltip: 'Cambiar Logo',
        ),
        const SizedBox(height: 16),
        // Botón para agregar inspector
        FloatingActionButton(
          onPressed: _agregarInspector,
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          child: const Icon(Icons.person_add),
          tooltip: 'Agregar Inspector',
        ),
      ],
    );
  }

  void _agregarInspector() {
    // Solo admin puede agregar inspectores
    if (!widget.authProvider.canManageUsers) {
      _mostrarErrorPermisos();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        onSave: (userData) {
          // El inspector se creará automáticamente en el grupo del admin
          _mostrarSnackBar('Inspector agregado exitosamente', Colors.green);
        },
        isSuperAdmin: false, // Admin no es super admin
        grupoId: widget.authProvider.grupoId,
        grupoNombre: widget.authProvider.grupoNombre,
      ),
    );
  }

  void _cambiarLogo(BuildContext context) {
    // Solo admin puede cambiar el logo
    if (!widget.authProvider.canManageLogo) {
      _mostrarErrorPermisos();
      return;
    }
    final adminController = context.read<AdminController>();
    adminController.changeLogo(context);
  }

  void _eliminarLogo(BuildContext context) {
    // Solo admin puede eliminar el logo
    if (!widget.authProvider.canManageLogo) {
      _mostrarErrorPermisos();
      return;
    }
    final adminController = context.read<AdminController>();
    adminController.deleteLogo(context);
  }

  void _configurarInterfaz() {
    // Solo admin puede configurar la interfaz
    if (!widget.authProvider.canManageLogo) {
      _mostrarErrorPermisos();
      return;
    }

    Navigator.pushNamed(
      context,
      '/interface_config',
      arguments: {
        'groupId': widget.authProvider.grupoId!,
        'groupData': {
          'nombre': widget.authProvider.grupoNombre,
          'descripcion': 'Grupo administrado por ${widget.authProvider.userData!['displayName']}',
        },
      },
    );
  }

  void _mostrarErrorPermisos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No tienes permisos para realizar esta acción'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}