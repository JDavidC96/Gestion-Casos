// lib/models/user_model.dart
class AppUser {
  final String uid;
  final String cedula;
  final String displayName;
  final String email;
  final String role; // 'super_admin', 'admin', 'user'
  final String? firmaBase64;
  final String? grupoId; // Para agrupar usuarios
  final String? grupoNombre;
  final DateTime createdAt;
  final Map<String, dynamic>? configInterfaz; // Configuración de interfaz

  AppUser({
    required this.uid,
    required this.cedula,
    required this.displayName,
    required this.email,
    required this.role,
    this.firmaBase64,
    this.grupoId,
    this.grupoNombre,
    required this.createdAt,
    this.configInterfaz,
  });

  Map<String, dynamic> toMap() {
    return {
      'cedula': cedula,
      'displayName': displayName,
      'email': email,
      'role': role,
      'firmaBase64': firmaBase64,
      'grupoId': grupoId,
      'grupoNombre': grupoNombre,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'configInterfaz': configInterfaz,
    };
  }

  static AppUser fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      cedula: map['cedula'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      firmaBase64: map['firmaBase64'],
      grupoId: map['grupoId'],
      grupoNombre: map['grupoNombre'],
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      configInterfaz: map['configInterfaz'],
    );
  }

  // Método para crear una copia del usuario con algunos campos actualizados
  AppUser copyWith({
    String? cedula,
    String? displayName,
    String? email,
    String? role,
    String? firmaBase64,
    String? grupoId,
    String? grupoNombre,
    DateTime? createdAt,
    Map<String, dynamic>? configInterfaz,
  }) {
    return AppUser(
      uid: uid,
      cedula: cedula ?? this.cedula,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      firmaBase64: firmaBase64 ?? this.firmaBase64,
      grupoId: grupoId ?? this.grupoId,
      grupoNombre: grupoNombre ?? this.grupoNombre,
      createdAt: createdAt ?? this.createdAt,
      configInterfaz: configInterfaz ?? this.configInterfaz,
    );
  }

  // Método para verificar si el usuario tiene un rol específico
  bool hasRole(String roleToCheck) {
    return role == roleToCheck;
  }

  // Método para verificar si el usuario puede acceder a un grupo específico
  bool canAccessGroup(String? groupIdToCheck) {
    if (role == 'super_admin') return true;
    return grupoId == groupIdToCheck;
  }

  // Método para verificar si el usuario puede editar en un grupo específico
  bool canEditInGroup(String? groupIdToCheck) {
    if (role == 'super_admin') return true;
    return grupoId == groupIdToCheck && (role == 'admin' || role == 'super_admin');
  }

  @override
  String toString() {
    return 'AppUser{uid: $uid, displayName: $displayName, email: $email, role: $role, grupo: $grupoNombre}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}