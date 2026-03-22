// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/empresas_provider.dart'; 
import '../controllers/admin_controller.dart';
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
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Center(
            child: Text(
              widget.authProvider.userData!['displayName'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ),
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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              // ── Tarjeta ID del grupo ─────────────────────────────
              _buildGrupoIdCard(),
              // Sección del logo (solo para admin de grupo)
              LogoSection(
                grupoId: widget.authProvider.grupoId,
                grupoNombre: widget.authProvider.grupoNombre,
                onChangeLogo: () => _cambiarLogo(context),
                onDeleteLogo: () => _eliminarLogo(context),
                onConfigureInterface: _configurarInterfaz,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        // Lista de inspectores del grupo — ocupa el espacio restante
        SliverFillRemaining(
          child: UsersListSection(
            grupoId: widget.authProvider.grupoId!,
            grupoNombre: widget.authProvider.grupoNombre,
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
          heroTag: 'fab_admin_config',
          onPressed: _configurarInterfaz,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          mini: true,
          tooltip: 'Configurar Interfaz',
          child: const Icon(Icons.settings),
        ),
        const SizedBox(height: 16),
        // Botón para cambiar logo
        FloatingActionButton(
          heroTag: 'fab_admin_logo',
          onPressed: () => _cambiarLogo(context),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          mini: true,
          tooltip: 'Cambiar Logo',
          child: const Icon(Icons.image),
        ),

      ],
    );
  }



  // ── Tarjeta con ID del grupo y botón para copiar/compartir ─────────────
  Widget _buildGrupoIdCard() {
    final grupoId     = widget.authProvider.grupoId ?? '';
    final grupoNombre = widget.authProvider.grupoNombre ?? 'Mi Grupo';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Ícono
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A11CB).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_work_outlined,
                    color: Color(0xFF6A11CB), size: 24),
              ),
              const SizedBox(width: 14),
              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grupoNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $grupoId',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Comparte este ID con nuevos inspectores',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Botón copiar
              Tooltip(
                message: 'Copiar ID del grupo',
                child: IconButton(
                  icon: const Icon(Icons.copy_outlined,
                      color: Color(0xFF6A11CB)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: grupoId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('ID copiado: \${grupoId.substring(0, 8)}...'),
                          ],
                        ),
                        backgroundColor: const Color(0xFF6A11CB),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
}