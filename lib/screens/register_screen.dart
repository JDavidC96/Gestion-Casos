// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart' as my_auth;

class RegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? googleUserData;
  
  const RegisterScreen({super.key, this.googleUserData});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cedulaController = TextEditingController();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _firmaController = TextEditingController();
  final _grupoIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Campos para nuevo grupo
  final _nuevoGrupoNombreController = TextEditingController();
  final _nuevoGrupoEmpresaController = TextEditingController();
  final _nuevoGrupoTelefonoController = TextEditingController();
  final _nuevoGrupoDireccionController = TextEditingController();

  String _selectedRole = 'user';
  bool _crearNuevoGrupo = false;
  bool _isLoading = false;
  bool _buscandoGrupo = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _grupoEncontradoNombre;
  String? _grupoEncontradoId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isGoogleRegistration = false;

  @override
  void initState() {
    super.initState();
    _isGoogleRegistration = widget.googleUserData != null;
    _prefillGoogleData();
  }

  void _prefillGoogleData() {
    if (widget.googleUserData != null) {
      final data = widget.googleUserData!;
      _emailController.text = data['email'] ?? '';
      _nombreController.text = data['displayName'] ?? '';
    }
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _firmaController.dispose();
    _grupoIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nuevoGrupoNombreController.dispose();
    _nuevoGrupoEmpresaController.dispose();
    _nuevoGrupoTelefonoController.dispose();
    _nuevoGrupoDireccionController.dispose();
    super.dispose();
  }

  // Método para buscar grupo en Firestore
  Future<void> _buscarGrupo(String grupoId) async {
    if (grupoId.isEmpty) {
      setState(() {
        _grupoEncontradoNombre = null;
        _grupoEncontradoId = null;
        _buscandoGrupo = false;
      });
      return;
    }

    setState(() {
      _buscandoGrupo = true;
      _grupoEncontradoNombre = null;
      _grupoEncontradoId = null;
    });

    try {
      final doc = await _firestore.collection('grupos').doc(grupoId).get();
      
      if (doc.exists && mounted) {
        setState(() {
          _grupoEncontradoNombre = doc.data()?['nombre'] ?? 'Sin nombre';
          _grupoEncontradoId = grupoId;
          _buscandoGrupo = false;
        });
      } else if (mounted) {
        setState(() {
          _grupoEncontradoNombre = null;
          _grupoEncontradoId = null;
          _buscandoGrupo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _grupoEncontradoNombre = null;
          _grupoEncontradoId = null;
          _buscandoGrupo = false;
        });
      }
    }
  }

  // Método para enviar correo real
  Future<void> _enviarCorreoNuevoGrupo() async {
    try {
      await _firestore.collection('solicitudes_grupos').add({
        'nombreGrupo': _nuevoGrupoNombreController.text.trim(),
        'nombreEmpresa': _nuevoGrupoEmpresaController.text.trim(),
        'telefono': _nuevoGrupoTelefonoController.text.trim(),
        'direccion': _nuevoGrupoDireccionController.text.trim(),
        'usuarioSolicitante': {
          'cedula': _cedulaController.text.trim(),
          'nombre': _nombreController.text.trim(),
          'email': _emailController.text.trim(),
          'rol': _selectedRole,
        },
        'fechaSolicitud': FieldValue.serverTimestamp(),
        'estado': 'pendiente',
        'emailDestino': 'covaret.tech@gmail.com',
      });

      print('Solicitud de nuevo grupo guardada en Firestore');
      
    } catch (e) {
      print('Error enviando solicitud de grupo: $e');
      throw e;
    }
  }

  // Método para registrar usuario en Firebase
  Future<void> _registrarUsuario() async {
    try {
      if (_isGoogleRegistration) {
        // Registro con Google
        final authProvider = Provider.of<my_auth.AuthProvider>(context, listen: false);
        final user = widget.googleUserData!['user'] as User;
        
        final success = await authProvider.completeGoogleRegistration(
          user.uid,
          _cedulaController.text.trim(),
          _nombreController.text.trim(),
          _emailController.text.trim(),
          _firmaController.text.trim(),
          _grupoEncontradoId,
          _grupoEncontradoNombre,
          _selectedRole,
        );

        if (!success) {
          throw Exception(authProvider.errorMessage ?? 'Error completando registro con Google');
        }
      } else {
        // Registro normal con email/password
        final user = await _crearUsuarioEnFirebase(
          _emailController.text.trim(),
          _passwordController.text,
        );

        // Guardar datos adicionales en Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'cedula': _cedulaController.text.trim(),
          'displayName': _nombreController.text.trim(),
          'email': _emailController.text.trim(),
          'firmaBase64': _firmaController.text.trim(),
          'grupoId': _grupoEncontradoId,
          'grupoNombre': _grupoEncontradoNombre,
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': user.uid,
        });

        print('Usuario registrado exitosamente: ${user.uid}');
      }
      
    } catch (e) {
      print('Error registrando usuario: $e');
      throw e;
    }
  }

  Future<User> _crearUsuarioEnFirebase(String email, String password) async {
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential.user!;
    } catch (e) {
      print('Error creando usuario en Firebase Auth: $e');
      throw e;
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación adicional para grupo
    if (!_crearNuevoGrupo && _grupoEncontradoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe buscar y validar un grupo existente'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_crearNuevoGrupo) {
        // Enviar correo para nuevo grupo
        await _enviarCorreoNuevoGrupo();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitud de nuevo grupo enviada. Te contactaremos pronto.'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Para nuevo grupo, volver con false (no completó registro completo)
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            Navigator.of(context).pop(false);
          });
        }

      } else {
        // Registrar usuario en grupo existente
        await _registrarUsuario();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isGoogleRegistration 
                  ? 'Registro con Google completado exitosamente.'
                  : 'Usuario registrado exitosamente.'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Devolver true si el registro se completó exitosamente
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (_isGoogleRegistration) {
              Navigator.of(context).pop(true);
            } else {
              Navigator.of(context).pop(false);
            }
          });
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleNuevoGrupo(bool? value) {
    setState(() {
      _crearNuevoGrupo = value ?? false;
      if (!_crearNuevoGrupo) {
        // Limpiar campos de nuevo grupo cuando se desactiva
        _nuevoGrupoNombreController.clear();
        _nuevoGrupoEmpresaController.clear();
        _nuevoGrupoTelefonoController.clear();
        _nuevoGrupoDireccionController.clear();
      } else {
        // Limpiar búsqueda de grupo cuando se activa nuevo grupo
        _grupoIdController.clear();
        _grupoEncontradoNombre = null;
        _grupoEncontradoId = null;
      }
    });
  }

  // Validación de contraseña segura (solo para registro normal)
  String? _validatePassword(String? value) {
    if (_isGoogleRegistration) return null;
    
    if (value == null || value.isEmpty) {
      return 'Ingrese una contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Debe contener al menos una mayúscula';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Debe contener al menos un número';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Debe contener al menos un carácter especial';
    }
    return null;
  }

  // Método para manejar el botón de retroceso
  void _handleBackButton() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isGoogleRegistration ? 'Completar Registro' : 'Registrar Usuario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackButton,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF43CEA2), Color(0xFF185A9D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Card(
                elevation: 8,
                color: Colors.white.withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          _isGoogleRegistration ? Icons.person : Icons.person_add,
                          size: 60,
                          color: const Color(0xFF43CEA2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isGoogleRegistration ? "Completar Registro" : "Registro de Usuario",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isGoogleRegistration 
                              ? "Complete la información faltante para finalizar su registro"
                              : "Complete la información del usuario",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Campo Cédula
                        TextFormField(
                          controller: _cedulaController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Cédula *",
                            prefixIcon: const Icon(Icons.badge),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingrese la cédula';
                            }
                            if (value.length < 6) {
                              return 'Cédula inválida';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Campo Nombre Completo
                        TextFormField(
                          controller: _nombreController,
                          decoration: InputDecoration(
                            labelText: "Nombre Completo *",
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingrese el nombre completo';
                            }
                            if (value.trim().split(' ').length < 2) {
                              return 'Ingrese nombre y apellido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Campo Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          readOnly: _isGoogleRegistration,
                          decoration: InputDecoration(
                            labelText: "Correo Electrónico *",
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingrese el correo electrónico';
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Ingrese un correo válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Campo Contraseña (solo para registro normal)
                        if (!_isGoogleRegistration) ...[
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Contraseña *",
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: "Mín. 6 caracteres, 1 mayúscula, 1 número, 1 especial",
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 16),

                          // Campo Confirmar Contraseña (solo para registro normal)
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: "Confirmar Contraseña *",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: _isGoogleRegistration ? null : (value) {
                              if (value == null || value.isEmpty) {
                                return 'Confirme la contraseña';
                              }
                              if (value != _passwordController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Campo Firma
                        TextFormField(
                          controller: _firmaController,
                          decoration: InputDecoration(
                            labelText: "Firma",
                            prefixIcon: const Icon(Icons.draw),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            hintText: "Base64 de la firma (opcional)",
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Selección de Rol
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: "Rol *",
                            prefixIcon: const Icon(Icons.manage_accounts),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('Empleado'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Administrador'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Seleccione un rol';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Opción para nuevo grupo
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _crearNuevoGrupo 
                                  ? const Color(0xFF43CEA2) 
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _crearNuevoGrupo,
                                      onChanged: _toggleNuevoGrupo,
                                      activeColor: const Color(0xFF43CEA2),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        "Mi empresa no está registrada",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_crearNuevoGrupo) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Complete la información de la empresa para solicitar un nuevo grupo:",
                                    style: TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Campos para nuevo grupo
                                  TextFormField(
                                    controller: _nuevoGrupoNombreController,
                                    decoration: InputDecoration(
                                      labelText: "Nombre del Grupo *",
                                      prefixIcon: const Icon(Icons.business),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: _crearNuevoGrupo ? (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Ingrese el nombre del grupo';
                                      }
                                      return null;
                                    } : null,
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  TextFormField(
                                    controller: _nuevoGrupoEmpresaController,
                                    decoration: InputDecoration(
                                      labelText: "Nombre de la Empresa *",
                                      prefixIcon: const Icon(Icons.business_center),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: _crearNuevoGrupo ? (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Ingrese el nombre de la empresa';
                                      }
                                      return null;
                                    } : null,
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  TextFormField(
                                    controller: _nuevoGrupoTelefonoController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      labelText: "Teléfono de Contacto *",
                                      prefixIcon: const Icon(Icons.phone),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: _crearNuevoGrupo ? (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Ingrese el teléfono';
                                      }
                                      return null;
                                    } : null,
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  TextFormField(
                                    controller: _nuevoGrupoDireccionController,
                                    decoration: InputDecoration(
                                      labelText: "Dirección *",
                                      prefixIcon: const Icon(Icons.location_on),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: _crearNuevoGrupo ? (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Ingrese la dirección';
                                      }
                                      return null;
                                    } : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        if (!_crearNuevoGrupo) ...[
                          const SizedBox(height: 16),
                          
                          // Búsqueda de grupo existente
                          TextFormField(
                            controller: _grupoIdController,
                            decoration: InputDecoration(
                              labelText: "ID del Grupo *",
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _buscandoGrupo
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.search),
                                      onPressed: () {
                                        if (_grupoIdController.text.isNotEmpty) {
                                          _buscarGrupo(_grupoIdController.text.trim());
                                        }
                                      },
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: "Ingrese el ID del grupo",
                            ),
                            onChanged: (value) {
                              // Búsqueda en tiempo real con debounce
                              if (value.length >= 3) {
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  if (_grupoIdController.text == value) {
                                    _buscarGrupo(value.trim());
                                  }
                                });
                              } else {
                                setState(() {
                                  _grupoEncontradoNombre = null;
                                  _grupoEncontradoId = null;
                                });
                              }
                            },
                            validator: _crearNuevoGrupo ? null : (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingrese el ID del grupo';
                              }
                              if (_grupoEncontradoId == null) {
                                return 'Debe validar el grupo primero';
                              }
                              return null;
                            },
                          ),
                          
                          // Resultado de la búsqueda
                          if (_grupoEncontradoNombre != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Grupo encontrado:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        Text(_grupoEncontradoNombre!),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_grupoIdController.text.isNotEmpty && !_buscandoGrupo) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Grupo no encontrado',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        const Text('Verifique el ID o solicite un nuevo grupo'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],

                        const SizedBox(height: 32),

                        // Botón de registro
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF43CEA2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleRegister,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _crearNuevoGrupo ? 'Solicitar Nuevo Grupo' : 'Registrar Usuario',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}