// lib/screens/register_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';
import '../providers/auth_provider.dart' as my_auth;
import '../services/camera_service.dart';

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
  final _grupoIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Firma
  late final SignatureController _signatureController;
  Uint8List? _firmaBytes;
  bool _firmaVacia = false; // para mostrar error de validación

  bool _isLoading = false;
  bool _buscandoGrupo = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _grupoEncontradoNombre;
  String? _grupoEncontradoId;
  Timer? _debounceTimer;
  bool _busquedaRealizada = false; // solo mostrar "no encontrado" tras buscar

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isGoogleRegistration = false;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
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
    _debounceTimer?.cancel();
    _cedulaController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _signatureController.dispose();
    _grupoIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Método para buscar grupo en Firestore
  Future<void> _buscarGrupo(String grupoId) async {
    final idLimpio = grupoId.trim();

    if (idLimpio.isEmpty) {
      setState(() {
        _grupoEncontradoNombre = null;
        _grupoEncontradoId = null;
        _buscandoGrupo = false;
        _busquedaRealizada = false;
      });
      return;
    }

    setState(() {
      _buscandoGrupo = true;
      _grupoEncontradoNombre = null;
      _grupoEncontradoId = null;
      _busquedaRealizada = false;
    });

    try {
      final doc = await _firestore.collection('grupos').doc(idLimpio).get();

      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          _grupoEncontradoNombre = doc.data()?['nombre'] ?? 'Sin nombre';
          _grupoEncontradoId = idLimpio;
          _buscandoGrupo = false;
          _busquedaRealizada = true;
        });
      } else {
        setState(() {
          _grupoEncontradoNombre = null;
          _grupoEncontradoId = null;
          _buscandoGrupo = false;
          _busquedaRealizada = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _grupoEncontradoNombre = null;
          _grupoEncontradoId = null;
          _buscandoGrupo = false;
          _busquedaRealizada = true;
        });
      }
    }
  }

  // Método para registrar usuario en Firebase
  Future<void> _registrarUsuario({String? firmaUrl}) async {
    
      if (_isGoogleRegistration) {
        // Registro con Google — firmaUrl ya se subió antes de llamar aquí
        final authProvider = Provider.of<my_auth.AuthProvider>(context, listen: false);
        final user = widget.googleUserData!['user'] as User;
        
        final success = await authProvider.completeGoogleRegistration(
          user.uid,
          _cedulaController.text.trim(),
          _nombreController.text.trim(),
          _emailController.text.trim(),
          firmaUrl,
          _grupoEncontradoId,
          _grupoEncontradoNombre,
          'inspector',
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

        // Guardar datos adicionales en Firestore (solo firmaUrl, sin base64)
        await _firestore.collection('users').doc(user.uid).set({
          'cedula': _cedulaController.text.trim(),
          'displayName': _nombreController.text.trim(),
          'email': _emailController.text.trim(),
          if (firmaUrl != null) 'firmaUrl': firmaUrl,
          'grupoId': _grupoEncontradoId,
          'grupoNombre': _grupoEncontradoNombre,
          'role': 'inspector',
          'createdAt': FieldValue.serverTimestamp(),
          'uid': user.uid,
        });
      }
      
    
  }

  Future<User> _crearUsuarioEnFirebase(String email, String password) async {
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential.user!;
    } on FirebaseAuthException catch (e) {
      // Si el correo ya existe en Auth (por un registro Google abandonado),
      // verificar si tiene documento en Firestore. Si NO lo tiene, es una
      // cuenta huérfana: vincular email/password y reutilizar ese uid.
      if (e.code == 'email-already-in-use') {
        final doc = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (doc.docs.isEmpty) {
          // Cuenta huérfana — iniciar sesión con Google para obtener el User
          // y vincularle las credenciales email/password.
          try {
            final credential = EmailAuthProvider.credential(
              email: email,
              password: password,
            );
            // Intentar iniciar sesión directamente con email (puede fallar si
            // solo existe el proveedor Google), en cuyo caso vinculamos.
            UserCredential linkedCredential;
            try {
              linkedCredential = await FirebaseAuth.instance
                  .signInWithEmailAndPassword(email: email, password: password);
            } on FirebaseAuthException {
              // El usuario existe pero con proveedor Google; vincular email/password
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null && currentUser.email == email) {
                linkedCredential =
                    await currentUser.linkWithCredential(credential);
              } else {
                // Forzar sign-in con Google primero no es posible aquí sin UI;
                // lanzar error descriptivo para que el usuario use Google.
                throw FirebaseAuthException(
                  code: 'account-exists-with-google',
                  message:
                      'Este correo ya fue registrado con Google. Inicia sesión con Google para completar tu registro.',
                );
              }
            }
            return linkedCredential.user!;
          } catch (linkError) {
            if (linkError is FirebaseAuthException &&
                linkError.code == 'account-exists-with-google') {
              rethrow;
            }
            rethrow;
          }
        }
      }
      rethrow;
    }
  }

  Future<void> _handleRegister() async {
    // Validar firma antes del form
    if (_signatureController.isEmpty) {
      setState(() => _firmaVacia = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La firma es obligatoria'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _firmaVacia = false);

    if (!_formKey.currentState!.validate()) return;

    // Validación de grupo
    if (_grupoEncontradoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe buscar y validar un grupo existente'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // Capturar bytes de la firma
      _firmaBytes = await _signatureController.toPngBytes();

      // Subir firma a Drive
      String? firmaUrl;
      if (_firmaBytes != null) {
        try {
          final cedulaId = _cedulaController.text.trim();
          final firmaResult = await CameraService.subirFirmaADrive(
            firmaBytes: _firmaBytes!,
            nombre: 'firma_registro_$cedulaId',
          );
          if (firmaResult.exitoso) {
            firmaUrl = firmaResult.url;
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${firmaResult.mensaje}. El registro continuará sin la firma.'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error subiendo la firma: $e. El registro continuará sin la firma.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }

      await _registrarUsuario(firmaUrl: firmaUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isGoogleRegistration
                ? 'Registro con Google completado exitosamente.'
                : 'Usuario registrado exitosamente.'),
            backgroundColor: Colors.green,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (_isGoogleRegistration) {
            Navigator.of(context).pop(true);
          } else {
            Navigator.of(context).pop(false);
          }
        });
      }

    } catch (e) {
      if (mounted) {
        String mensajeError = e.toString().replaceAll('Exception: ', '');
        if (e is FirebaseAuthException &&
            e.code == 'account-exists-with-google') {
          mensajeError = e.message ??
              'Este correo ya fue registrado con Google. Usa el botón "Continuar con Google".';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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

                        // Campo Firma (obligatorio)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.draw, color: Color(0xFF43CEA2)),
                                const SizedBox(width: 8),
                                const Text(
                                  "Firma *",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () {
                                    _signatureController.clear();
                                    setState(() => _firmaVacia = false);
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text("Limpiar"),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _firmaVacia ? Colors.red : Colors.grey.shade400,
                                  width: _firmaVacia ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Signature(
                                  controller: _signatureController,
                                  height: 160,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            if (_firmaVacia)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 12),
                                child: Text(
                                  'La firma es obligatoria',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              "Dibuje su firma en el recuadro",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
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
                              _debounceTimer?.cancel();
                              if (value.trim().isEmpty) {
                                setState(() {
                                  _grupoEncontradoNombre = null;
                                  _grupoEncontradoId = null;
                                  _busquedaRealizada = false;
                                });
                                return;
                              }
                              _debounceTimer = Timer(
                                const Duration(milliseconds: 600),
                                () => _buscarGrupo(value),
                              );
                            },
                            validator: (value) {
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
                          ] else if (_busquedaRealizada && _grupoEncontradoNombre == null && !_buscandoGrupo) ...[
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
                                        const Text('Verifique el ID ingresado'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                              : const Text(
                                  'Registrar Usuario',
                                  style: TextStyle(
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