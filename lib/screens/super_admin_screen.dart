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
import '../widgets/assign_empresas_dialog.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  // 0 = Usuarios, 1 = Grupos, 2 = Solicitudes
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

  // ─── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return AppBar(
      title: const Text('Super Administrador'),
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

  // ─── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildUsersTab(),
          _buildGroupsTab(),
          _buildSolicitudesTab(),
        ],
      ),
    );
  }

  // ─── Tab Usuarios ─────────────────────────────────────────────────────────

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
            onAction: (action, userData) =>
                _handleUserAction(action, doc.id, userData),
          );
        },
      ),
    );
  }

  // ─── Tab Grupos ───────────────────────────────────────────────────────────

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

  // ─── Tab Solicitudes ──────────────────────────────────────────────────────

  Widget _buildSolicitudesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('solicitudes_grupos')
          .orderBy('fechaSolicitud', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error cargando solicitudes: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptySolicitudesState();
        }

        final docs = snapshot.data!.docs;
        final pendientes = docs.where((d) =>
            (d.data() as Map<String, dynamic>)['estado'] == 'pendiente').toList();
        final procesadas = docs.where((d) =>
            (d.data() as Map<String, dynamic>)['estado'] != 'pendiente').toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pendientes.isNotEmpty) ...[
              _sectionHeader(
                '⏳ Pendientes (${pendientes.length})',
                Colors.orange.shade200,
              ),
              const SizedBox(height: 8),
              ...pendientes.map((doc) => _buildSolicitudCard(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  )),
              const SizedBox(height: 20),
            ],
            if (procesadas.isNotEmpty) ...[
              _sectionHeader(
                '✅ Procesadas (${procesadas.length})',
                Colors.white54,
              ),
              const SizedBox(height: 8),
              ...procesadas.map((doc) => _buildSolicitudCard(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                    readOnly: true,
                  )),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSolicitudCard(
    String solicitudId,
    Map<String, dynamic> data, {
    bool readOnly = false,
  }) {
    final estado = data['estado'] ?? 'pendiente';
    final isPendiente = estado == 'pendiente';
    final isAprobada = estado == 'aprobado';

    Color estadoColor;
    IconData estadoIcon;
    if (isAprobada) {
      estadoColor = Colors.green;
      estadoIcon = Icons.check_circle;
    } else if (estado == 'rechazado') {
      estadoColor = Colors.red;
      estadoIcon = Icons.cancel;
    } else {
      estadoColor = Colors.orange;
      estadoIcon = Icons.hourglass_top_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPendiente
            ? const BorderSide(color: Colors.orange, width: 1.5)
            : BorderSide.none,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: data['logoUrl'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    data['logoUrl'],
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultLogo(),
                  ),
                )
              : _defaultLogo(),
          title: Text(
            data['nombreEmpresa'] ?? 'Sin nombre',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NIT: ${data['nit'] ?? '-'}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(estadoIcon, size: 14, color: estadoColor),
                  const SizedBox(width: 4),
                  Text(
                    estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: estadoColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            _infoRow(Icons.store, 'Empresa', data['nombreEmpresa']),
            _infoRow(Icons.numbers, 'NIT', data['nit']),
            _infoRow(Icons.account_balance, 'Razón Social', data['razonSocial']),
            _infoRow(Icons.description, 'Descripción', data['descripcion']),
            const Divider(height: 24),
            _infoRow(Icons.person, 'Administrador', data['adminNombre']),
            _infoRow(Icons.email, 'Correo', data['adminEmail']),
            // Firma
            if (data['firmaUrl'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.draw, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Firma:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  data['firmaUrl'],
                  height: 90,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('No se pudo cargar la firma'),
                ),
              ),
            ],
            if (isPendiente) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _confirmarRechazo(solicitudId, data),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _confirmarAprobacion(solicitudId, data),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (!isPendiente)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  children: [
                    Icon(estadoIcon, color: estadoColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      isAprobada
                          ? 'Grupo creado automáticamente'
                          : 'Solicitud rechazada',
                      style: TextStyle(
                          color: estadoColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _defaultLogo() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF6A11CB).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.business, color: Color(0xFF6A11CB), size: 26),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.visible),
          ),
        ],
      ),
    );
  }

  // ─── Lógica Aprobar / Rechazar ────────────────────────────────────────────

  Future<void> _confirmarAprobacion(
      String solicitudId, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Aprobar solicitud'),
          ],
        ),
        content: Text(
          '¿Deseas aprobar y crear el grupo para la empresa\n'
          '"${data['nombreEmpresa']}"?\n\n'
          'Se creará el grupo automáticamente y el administrador\n'
          '"${data['adminNombre']}" quedará asignado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Aprobar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _aprobarSolicitud(solicitudId, data);
    }
  }

  Future<void> _confirmarRechazo(
      String solicitudId, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Rechazar solicitud'),
          ],
        ),
        content: Text(
          '¿Deseas rechazar la solicitud de\n"${data['nombreEmpresa']}"?\n\n'
          'El administrador NO tendrá acceso hasta que se apruebe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _rechazarSolicitud(solicitudId);
    }
  }

  /// Aprueba la solicitud:
  /// 1. Crea el grupo en la colección `grupos`
  /// 2. Asigna grupoId y grupoNombre al usuario admin
  /// 3. Marca la solicitud como 'aprobado'
  Future<void> _aprobarSolicitud(
      String solicitudId, Map<String, dynamic> data) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Crear el grupo
      final grupoRef = await firestore.collection('grupos').add({
        'nombre':       data['nombreEmpresa'] ?? '',
        'razonSocial':  data['razonSocial'] ?? '',
        'nit':          data['nit'] ?? '',
        'descripcion':  data['descripcion'] ?? '',
        if (data['logoUrl'] != null) 'logoUrl': data['logoUrl'],
        'adminUid':     data['adminUid'] ?? '',
        'adminEmail':   data['adminEmail'] ?? '',
        'adminNombre':  data['adminNombre'] ?? '',
        'creadoPor':    'super_admin',
        'fechaCreacion': FieldValue.serverTimestamp(),
        'activo':       true,
      });

      // 2. Actualizar usuario admin con el grupoId
      if (data['adminUid'] != null) {
        await firestore.collection('users').doc(data['adminUid']).update({
          'grupoId':     grupoRef.id,
          'grupoNombre': data['nombreEmpresa'] ?? '',
        });
      }

      // 3. Marcar solicitud como aprobada
      await firestore
          .collection('solicitudes_grupos')
          .doc(solicitudId)
          .update({
        'estado':           'aprobado',
        'grupoId':          grupoRef.id,
        'fechaAprobacion':  FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _mostrarSnackBar(
          '✅ Grupo "${data['nombreEmpresa']}" creado exitosamente',
          Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Error al aprobar solicitud: $e', Colors.red);
      }
    }
  }

  Future<void> _rechazarSolicitud(String solicitudId) async {
    try {
      await FirebaseFirestore.instance
          .collection('solicitudes_grupos')
          .doc(solicitudId)
          .update({
        'estado':         'rechazado',
        'fechaRechazo':   FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _mostrarSnackBar('Solicitud rechazada', Colors.orange);
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Error al rechazar solicitud: $e', Colors.red);
      }
    }
  }

  // ─── Estados vacíos / error ───────────────────────────────────────────────

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(error,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center),
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
          const Text('No hay usuarios registrados',
              style: TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 8),
          Text('Presiona el botón + para agregar el primer usuario',
              style: TextStyle(
                  fontSize: 14, color: Colors.white70.withOpacity(0.8)),
              textAlign: TextAlign.center),
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
          const Text('No hay grupos registrados',
              style: TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 8),
          Text('Presiona el botón + para agregar el primer grupo',
              style: TextStyle(
                  fontSize: 14, color: Colors.white70.withOpacity(0.8)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptySolicitudesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 80, color: Colors.white70),
          const SizedBox(height: 16),
          const Text('No hay solicitudes pendientes',
              style: TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 8),
          Text('Las nuevas solicitudes de grupos aparecerán aquí',
              style: TextStyle(
                  fontSize: 14, color: Colors.white70.withOpacity(0.8)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─── Bottom Nav ───────────────────────────────────────────────────────────

  Widget _buildBottomNavBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('solicitudes_grupos')
          .where('estado', isEqualTo: 'pendiente')
          .snapshots(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.docs.length ?? 0;

        return BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Usuarios',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.group),
              label: 'Grupos',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.mark_email_unread_outlined),
                  if (pendingCount > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Solicitudes',
            ),
          ],
          backgroundColor: Colors.white,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
        );
      },
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────────────────

  Widget _buildFloatingActionButton() {
    // No FAB en la pestaña de solicitudes
    if (_selectedIndex == 2) return const SizedBox.shrink();
    return FloatingActionButton(
      onPressed: _selectedIndex == 0 ? _agregarUsuario : _agregarGrupo,
      backgroundColor: Colors.orange,
      foregroundColor: Colors.white,
      tooltip: _selectedIndex == 0 ? 'Agregar Usuario' : 'Agregar Grupo',
      child: const Icon(Icons.add),
    );
  }

  // ─── Acciones usuarios / grupos ───────────────────────────────────────────

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
          UserService.createGrupo(
              groupData['nombre'], groupData['descripcion']);
          _mostrarSnackBar('Grupo creado exitosamente', Colors.green);
        },
      ),
    );
  }

  void _handleUserAction(
      String action, String userId, Map<String, dynamic> userData) {
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

  void _handleGroupAction(
      String action, String groupId, Map<String, dynamic> groupData) {
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
    final empresasProvider =
        Provider.of<EmpresasProvider>(context, listen: false);
    final esInspector = userData['role'] == 'inspector' ||
        userData['role'] == 'superinspector';
    if (!esInspector) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Solo se pueden asignar empresas a inspectores'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AssignEmpresasDialog(
        userId: userId,
        userDisplayName: userData['displayName'] ?? 'Usuario',
        empresasActuales:
            (userData['empresasAsignadas'] as List<dynamic>?)?.cast<String>() ??
                [],
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
    Navigator.pushNamed(context, '/interface_config', arguments: {
      'groupId': groupId,
      'groupData': groupData,
    });
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

  Future<void> _confirmarEliminarUsuario(
      String userId, String displayName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content:
            Text('¿Estás seguro de eliminar al usuario "$displayName"?'),
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
    if (result == true) await _eliminarUsuario(userId);
  }

  Future<void> _confirmarEliminarGrupo(
      String groupId, String groupName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
            '¿Estás seguro de eliminar el grupo "$groupName"? Esta acción eliminará todos los usuarios y datos asociados.'),
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
    if (result == true) await _eliminarGrupo(groupId);
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

  Future<void> _confirmarLogout(
      BuildContext context, AuthProvider authProvider) async {
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
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
    ));
  }
}