// lib/screens/super_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../providers/auth_provider.dart';
import '../providers/empresas_provider.dart'; 
import '../widgets/user_form_dialog.dart';
import '../widgets/group_form_dialog.dart';
import '../widgets/group_users_dialog.dart';
import '../widgets/user_card.dart';
import '../widgets/group_card.dart';
import '../widgets/assign_empresas_dialog.dart'; // Asegúrate de importar este widget

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EmpresasProvider()),
      ],
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppBar(context),
        body: _buildBody(),
        floatingActionButton: _buildFloatingActionButton(),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return AppBar(
      title: const Text("Super Administrador"),
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
        _buildUserInfo(authProvider),
        _buildLogoutButton(context, authProvider),
      ],
    );
  }

  Widget _buildUserInfo(AuthProvider authProvider) {
    return Padding(
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
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    return IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () => _confirmarLogout(context, authProvider),
      tooltip: 'Cerrar Sesión',
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
      child: _selectedIndex == 0 ? _buildUsersTab() : _buildGroupsTab(),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: UserService.getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error cargando usuarios: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyUsersState();
        }

        return _buildUsersList(snapshot.data!.docs);
      },
    );
  }

  Widget _buildGroupsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: UserService.getGruposStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error cargando grupos: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyGroupsState();
        }

        return _buildGroupsList(snapshot.data!.docs);
      },
    );
  }

  Widget _buildUsersList(List<QueryDocumentSnapshot> users) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final doc = users[index];
          final data = doc.data() as Map<String, dynamic>;
          
          return UserCard(
            userData: data,
            userId: doc.id,
            onAction: (action, userData) => _handleUserAction(action, doc.id, userData),
          );
        },
      ),
    );
  }

  Widget _buildGroupsList(List<QueryDocumentSnapshot> groups) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final doc = groups[index];
          final data = doc.data() as Map<String, dynamic>;
          
          return GroupCard(
            groupId: doc.id,
            groupData: data,
            onAction: _handleGroupAction,
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              error,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUsersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.white70),
          const SizedBox(height: 16),
          const Text(
            'No hay usuarios registrados',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el botón + para agregar el primer usuario',
            style: TextStyle(fontSize: 14, color: Colors.white70.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyGroupsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_outlined, size: 80, color: Colors.white70),
          const SizedBox(height: 16),
          const Text(
            'No hay grupos registrados',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el botón + para agregar el primer grupo',
            style: TextStyle(fontSize: 14, color: Colors.white70.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Usuarios',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group),
          label: 'Grupos',
        ),
      ],
      backgroundColor: Colors.white,
      selectedItemColor: Colors.orange,
      unselectedItemColor: Colors.grey,
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _selectedIndex == 0 ? _agregarUsuario : _agregarGrupo,
      backgroundColor: Colors.orange,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
      tooltip: _selectedIndex == 0 ? 'Agregar Usuario' : 'Agregar Grupo',
    );
  }

  void _agregarUsuario() {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        onSave: (userData) {
          _mostrarSnackBar('Usuario creado exitosamente', Colors.green);
        },
        isSuperAdmin: true,
      ),
    );
  }

  void _agregarGrupo() {
    showDialog(
      context: context,
      builder: (context) => GroupFormDialog(
        onSave: (groupData) {
          UserService.createGrupo(groupData['nombre'], groupData['descripcion']);
          _mostrarSnackBar('Grupo creado exitosamente', Colors.green);
        },
      ),
    );
  }

  void _handleUserAction(String action, String userId, Map<String, dynamic> userData) {
    switch (action) {
      case 'edit':
        _editarUsuario(userId, userData);
        break;
      case 'assign_empresas':
        _asignarEmpresas(userId, userData);
        break;
      case 'delete':
        _confirmarEliminarUsuario(userId, userData['displayName']);
        break;
    }
  }

  void _handleGroupAction(String action, String groupId, Map<String, dynamic> groupData) {
    switch (action) {
      case 'users':
        _gestionarUsuarios(groupId, groupData);
        break;
      case 'config':
        _configurarInterfaz(groupId, groupData);
        break;
      case 'edit':
        _editarGrupo(groupId, groupData);
        break;
      case 'delete':
        _confirmarEliminarGrupo(groupId, groupData['nombre']);
        break;
    }
  }

  void _asignarEmpresas(String userId, Map<String, dynamic> userData) {
    final empresasProvider = Provider.of<EmpresasProvider>(context, listen: false);
    
    // Verificar si es inspector
    final esInspector = userData['role'] == 'inspector' || userData['role'] == 'superinspector';
    if (!esInspector) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se pueden asignar empresas a inspectores'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AssignEmpresasDialog(
        userId: userId,
        userDisplayName: userData['displayName'] ?? 'Usuario',
        empresasActuales: (userData['empresasAsignadas'] as List<dynamic>?)?.cast<String>() ?? [],
        empresasProvider: empresasProvider,
      ),
    ).then((result) {
      if (result == true && context.mounted) {
        empresasProvider.refreshEmpresasForUser(userId);
        _mostrarSnackBar('Empresas asignadas exitosamente', Colors.green);
      }
    });
  }

  void _gestionarUsuarios(String groupId, Map<String, dynamic> groupData) {
    showDialog(
      context: context,
      builder: (context) => GroupUsersDialog(
        groupId: groupId,
        groupName: groupData['nombre'],
      ),
    );
  }

  void _configurarInterfaz(String groupId, Map<String, dynamic> groupData) {
    // Navegar a pantalla de configuración de interfaz
    Navigator.pushNamed(
      context,
      '/interface_config',
      arguments: {
        'groupId': groupId,
        'groupData': groupData,
      },
    );
  }

  void _editarUsuario(String userId, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        userData: userData,
        userId: userId,
        onSave: (updatedData) {
          UserService.updateUser(userId, updatedData);
          _mostrarSnackBar('Usuario actualizado exitosamente', Colors.green);
        },
        isSuperAdmin: true,
      ),
    );
  }

  void _editarGrupo(String groupId, Map<String, dynamic> groupData) {
    showDialog(
      context: context,
      builder: (context) => GroupFormDialog(
        groupId: groupId,
        groupData: groupData,
        onSave: (updatedData) {
          UserService.updateGrupo(groupId, updatedData);
          _mostrarSnackBar('Grupo actualizado exitosamente', Colors.green);
        },
      ),
    );
  }

  Future<void> _confirmarEliminarUsuario(String userId, String displayName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar al usuario "$displayName"?'),
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

    if (result == true) {
      await _eliminarUsuario(userId);
    }
  }

  Future<void> _confirmarEliminarGrupo(String groupId, String groupName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar el grupo "$groupName"? Esta acción eliminará todos los usuarios y datos asociados.'),
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

    if (result == true) {
      await _eliminarGrupo(groupId);
    }
  }

  Future<void> _eliminarUsuario(String userId) async {
    try {
      await UserService.deleteUser(userId);
      _mostrarSnackBar('Usuario eliminado exitosamente', Colors.green);
    } catch (e) {
      _mostrarSnackBar('Error al eliminar usuario: $e', Colors.red);
    }
  }

  Future<void> _eliminarGrupo(String groupId) async {
    try {
      await UserService.deleteGrupo(groupId);
      _mostrarSnackBar('Grupo eliminado exitosamente', Colors.green);
    } catch (e) {
      _mostrarSnackBar('Error al eliminar grupo: $e', Colors.red);
    }
  }

  Future<void> _confirmarLogout(BuildContext context, AuthProvider authProvider) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (result == true) {
      await authProvider.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
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