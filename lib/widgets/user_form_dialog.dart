// lib/widgets/user_form_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';
import '../services/user_service.dart';

class UserFormDialog extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final String? userId;
  final Function(Map<String, dynamic>) onSave;
  final bool isSuperAdmin;
  final String? grupoId;
  final String? grupoNombre;

  const UserFormDialog({
    super.key,
    this.userData,
    this.userId,
    required this.onSave,
    required this.isSuperAdmin,
    this.grupoId,
    this.grupoNombre,
  });

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cedulaController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedRole = 'inspector'; // Cambiado de 'user' a 'inspector'
  Uint8List? _firma;
  final SignatureController _signatureController = SignatureController();
  bool _firmaGuardada = false;

  @override
  void initState() {
    super.initState();
    if (widget.userData != null) {
      _cedulaController.text = widget.userData!['cedula'] ?? '';
      _displayNameController.text = widget.userData!['displayName'] ?? '';
      _emailController.text = widget.userData!['email'] ?? '';
      _selectedRole = widget.userData!['role'] ?? 'inspector'; // Cambiado de 'user' a 'inspector'
      
      // Cargar firma existente si está editando
      if (widget.userData!['firmaBase64'] != null) {
        _firma = base64Decode(widget.userData!['firmaBase64']);
        _firmaGuardada = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.userData == null ? 'Crear Usuario' : 'Editar Usuario',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _cedulaController,
                          decoration: const InputDecoration(
                            labelText: 'Cédula',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'La cédula es requerida';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre Completo',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El nombre es requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El email es requerido';
                            }
                            if (!value.contains('@')) {
                              return 'Email inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (widget.userData == null)
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Contraseña',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La contraseña es requerida';
                              }
                              if (value.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            },
                          ),
                        if (widget.userData == null) const SizedBox(height: 16),
                        if (widget.isSuperAdmin)
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            items: const [
                              DropdownMenuItem(value: 'super_admin', child: Text('Super Administrador')),
                              DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                              DropdownMenuItem(value: 'superinspector', child: Text('Super Inspector')),
                              DropdownMenuItem(value: 'inspector', child: Text('Inspector')),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedRole = value!);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Rol',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        if (widget.isSuperAdmin) const SizedBox(height: 16),
                        
                        // Información del grupo (solo lectura)
                        if (widget.grupoNombre != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.group, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Grupo: ${widget.grupoNombre}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.grupoNombre != null) const SizedBox(height: 16),
                        
                        // Sección de Firma (OBLIGATORIA)
                        const Text(
                          'Firma del Usuario *',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _firmaGuardada 
                            ? 'Firma registrada correctamente'
                            : 'Debe capturar su firma para continuar',
                          style: TextStyle(
                            color: _firmaGuardada ? Colors.green : Colors.red,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _firmaGuardada ? Colors.green : Colors.grey,
                              width: _firmaGuardada ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Signature(
                            controller: _signatureController,
                            backgroundColor: Colors.grey[100]!,
                            height: 150,
                            width: double.infinity,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _signatureController.clear,
                              child: const Text('Limpiar Firma'),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: _capturarFirma,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _firmaGuardada ? Colors.green : Colors.blue,
                              ),
                              child: Text(
                                _firmaGuardada ? 'Firma Guardada ✓' : 'Guardar Firma',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        
                        // Mostrar firma actual si está editando
                        if (widget.userData != null && _firma != null)
                          Column(
                            children: [
                              const SizedBox(height: 16),
                              const Text(
                                'Firma actual:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.green),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.memory(
                                  _firma!,
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _eliminarFirma,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Eliminar firma actual'),
                              ),
                            ],
                          ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Botones en la parte inferior
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _firmaGuardada ? _guardarUsuario : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _firmaGuardada ? Colors.green : Colors.grey,
                      ),
                      child: Text(
                        _firmaGuardada ? 'Guardar Usuario' : 'Falta Firma',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _capturarFirma() async {
    final data = await _signatureController.toPngBytes();
    if (data != null && data.isNotEmpty) {
      setState(() {
        _firma = data;
        _firmaGuardada = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firma guardada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, realice una firma antes de guardar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _eliminarFirma() {
    setState(() {
      _firma = null;
      _firmaGuardada = false;
      _signatureController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Firma eliminada'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _guardarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar que la firma esté presente
    if (!_firmaGuardada || _firma == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe capturar la firma antes de guardar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final userData = {
        'cedula': _cedulaController.text.trim(),
        'displayName': _displayNameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'firmaBase64': base64Encode(_firma!), // Siempre requerida
        if (widget.grupoId != null) 'grupoId': widget.grupoId,
        if (widget.grupoNombre != null) 'grupoNombre': widget.grupoNombre,
      };

      if (widget.userData == null) {
        // Crear nuevo usuario
        await UserService.createUser(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          cedula: _cedulaController.text.trim(),
          displayName: _displayNameController.text.trim(),
          role: _selectedRole,
          firmaBase64: base64Encode(_firma!), // Siempre requerida
          grupoId: widget.grupoId,
          grupoNombre: widget.grupoNombre,
        );
      } else {
        // Actualizar usuario existente
        await UserService.updateUser(widget.userId!, userData);
      }

      widget.onSave(userData);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _signatureController.dispose();
    super.dispose();
  }
}