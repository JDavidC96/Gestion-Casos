// lib/screens/request_group_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import '../services/camera_service.dart';

class RequestGroupScreen extends StatefulWidget {
  const RequestGroupScreen({super.key});

  @override
  State<RequestGroupScreen> createState() => _RequestGroupScreenState();
}

class _RequestGroupScreenState extends State<RequestGroupScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // Controllers — empresa
  final _nitController           = TextEditingController();
  final _nombreEmpresaController = TextEditingController();
  final _razonSocialController   = TextEditingController();
  final _descripcionController   = TextEditingController();

  // Controllers — administrador
  final _cedulaController          = TextEditingController();
  final _nombreController          = TextEditingController();
  final _emailController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Firma
  late final SignatureController _signatureController;
  Uint8List? _firmaBytes;
  bool _firmaVacia = false;

  // Logo
  String? _logoUrl;
  bool _subiendoLogo = false;

  // NIT state
  Timer? _nitDebounce;
  bool   _verificandoNit = false;
  bool   _nitYaEnviado   = false;

  // Flujo
  bool _isLoading       = false;
  bool _solicitudEnviada = false;

  // UI
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _nitDebounce?.cancel();
    _nitController.dispose();
    _nombreEmpresaController.dispose();
    _razonSocialController.dispose();
    _descripcionController.dispose();
    _cedulaController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // ─── Verificar NIT ────────────────────────────────────────────────────────

  void _onNitChanged(String value) {
    _nitDebounce?.cancel();
    final nit = value.trim();
    if (nit.length < 5) {
      setState(() => _nitYaEnviado = false);
      return;
    }
    setState(() => _verificandoNit = true);
    _nitDebounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        final solicitudes = await _firestore
            .collection('solicitudes_grupos')
            .where('nit', isEqualTo: nit)
            .limit(1)
            .get();
        final grupos = await _firestore
            .collection('grupos')
            .where('nit', isEqualTo: nit)
            .limit(1)
            .get();
        if (mounted) {
          setState(() {
            _nitYaEnviado   = solicitudes.docs.isNotEmpty || grupos.docs.isNotEmpty;
            _verificandoNit = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _verificandoNit = false);
      }
    });
  }

  // ─── Logo ─────────────────────────────────────────────────────────────────

  Future<void> _seleccionarLogo() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null) return;
    setState(() => _subiendoLogo = true);
    try {
      final result = await CameraService.subirFotoADrive(image);
      if (result.exitoso && result.url != null && mounted) {
        setState(() => _logoUrl = result.url);
      } else if (mounted) {
        _showSnack(result.mensaje, Colors.orange);
      }
    } catch (e) {
      if (mounted) _showSnack('Error subiendo logo: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  // ─── Enviar solicitud ─────────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (_nitYaEnviado || _verificandoNit) return;

    if (_signatureController.isEmpty) {
      setState(() => _firmaVacia = true);
      _showSnack('La firma es obligatoria', Colors.red);
      return;
    }
    setState(() => _firmaVacia = false);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final nitLimpio = _nitController.text.trim();

      // Re-verificar NIT justo antes de guardar
      final nitCheck = await _firestore
          .collection('solicitudes_grupos')
          .where('nit', isEqualTo: nitLimpio)
          .limit(1)
          .get();
      if (nitCheck.docs.isNotEmpty) {
        setState(() { _nitYaEnviado = true; _isLoading = false; });
        return;
      }

      // 1. Subir firma a Drive
      _firmaBytes = await _signatureController.toPngBytes();
      String? firmaUrl;
      if (_firmaBytes != null) {
        final firmaResult = await CameraService.subirFirmaADrive(
          firmaBytes: _firmaBytes!,
          nombre: 'firma_admin_${_cedulaController.text.trim()}',
        );
        if (firmaResult.exitoso) {
          firmaUrl = firmaResult.url;
        } else {
          _showSnack(firmaResult.mensaje, Colors.orange);
        }
      }

      // 2. Crear usuario admin en Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final uid = credential.user!.uid;

      // 3. Crear documento del usuario admin en Firestore
      //    grupoId queda null hasta que el super_admin apruebe y cree el grupo
      await _firestore.collection('users').doc(uid).set({
        'uid':         uid,
        'cedula':      _cedulaController.text.trim(),
        'displayName': _nombreController.text.trim(),
        'email':       _emailController.text.trim(),
        'role':        'admin',
        'grupoId':     null,
        'grupoNombre': null,
        if (firmaUrl != null) 'firmaUrl': firmaUrl,
        'createdAt':   FieldValue.serverTimestamp(),
      });

      // 4. Guardar solicitud del grupo — el super_admin la aprueba,
      //    crea el grupo y luego actualiza grupoId en el usuario
      await _firestore.collection('solicitudes_grupos').add({
        'nit':           nitLimpio,
        'nombreEmpresa': _nombreEmpresaController.text.trim(),
        'razonSocial':   _razonSocialController.text.trim(),
        'descripcion':   _descripcionController.text.trim(),
        if (_logoUrl != null) 'logoUrl': _logoUrl,
        'adminUid':      uid,
        'adminEmail':    _emailController.text.trim(),
        'adminNombre':   _nombreController.text.trim(),
        'estado':        'pendiente',
        'correoEnviado': false,
        'emailDestino':  'covaret.tech@gmail.com',
        'fechaSolicitud': FieldValue.serverTimestamp(),
      });

      if (mounted) setState(() => _solicitudEnviada = true);
    } on FirebaseAuthException catch (e) {
      _showSnack(_authError(e), Colors.red);
    } catch (e) {
      _showSnack('Error enviando solicitud: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return 'Este correo ya está registrado';
      case 'weak-password':        return 'La contraseña es muy débil';
      case 'invalid-email':        return 'Correo electrónico inválido';
      default:                     return 'Error: ${e.message}';
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty)        return 'Ingrese una contraseña';
    if (v.length < 6)                  return 'Mínimo 6 caracteres';
    if (!v.contains(RegExp(r'[A-Z]'))) return 'Debe contener una mayúscula';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Debe contener un número';
    if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Debe contener un carácter especial';
    }
    return null;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Empresa'),
        backgroundColor: const Color(0xFF185A9D),
        foregroundColor: Colors.white,
        elevation: 0,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 8,
              color: Colors.white.withOpacity(0.95),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _solicitudEnviada
                    ? _buildConfirmacion()
                    : _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Pantalla de confirmación ─────────────────────────────────────────────

  Widget _buildConfirmacion() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              size: 64, color: Color(0xFF43CEA2)),
        ),
        const SizedBox(height: 24),
        const Text(
          '¡Solicitud Enviada!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F8FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF185A9D).withOpacity(0.2)),
          ),
          child: Column(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: Color(0xFF185A9D), size: 32),
              const SizedBox(height: 10),
              const Text(
                'Esperando confirmación',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF185A9D)),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu cuenta ha sido creada. Hemos recibido la\n'
                'solicitud para registrar la empresa\n'
                '"${_nombreEmpresaController.text.trim()}".\n\n'
                'Nuestro equipo la revisará y te notificará al\n'
                'correo: ${_emailController.text.trim()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: Colors.black87, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF185A9D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 40, vertical: 14),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver al inicio',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── Formulario ───────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.business, size: 60, color: Color(0xFF43CEA2)),
          const SizedBox(height: 12),
          const Text(
            'Registrar Empresa',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Completa los datos para solicitar el registro',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 28),

          // ── Datos empresa ──────────────────────────────────────────────
          _sectionLabel('Datos de la Empresa', Icons.business_center),
          const SizedBox(height: 12),

          // NIT
          TextFormField(
            controller: _nitController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'NIT *',
              prefixIcon: const Icon(Icons.numbers),
              suffixIcon: _verificandoNit
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ))
                  : _nitYaEnviado
                      ? const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange)
                      : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _onNitChanged,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingrese el NIT';
              if (v.trim().length < 5) return 'NIT inválido';
              return null;
            },
          ),

          // Banner NIT ya existe
          if (_nitYaEnviado) ...[
            const SizedBox(height: 8),
            _bannerEspera(
              'Ya existe una solicitud registrada con este NIT.\n'
              'Por favor espera la confirmación de nuestro equipo.',
            ),
          ],

          const SizedBox(height: 14),

          _textField(
            controller: _nombreEmpresaController,
            label: 'Nombre de la Empresa *',
            icon: Icons.store,
            enabled: !_nitYaEnviado,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ingrese el nombre de la empresa' : null,
          ),
          const SizedBox(height: 14),

          _textField(
            controller: _razonSocialController,
            label: 'Razón Social *',
            icon: Icons.account_balance,
            enabled: !_nitYaEnviado,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ingrese la razón social' : null,
          ),
          const SizedBox(height: 14),

          _textField(
            controller: _descripcionController,
            label: 'Descripción *',
            icon: Icons.description,
            maxLines: 3,
            enabled: !_nitYaEnviado,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ingrese una descripción' : null,
          ),
          const SizedBox(height: 14),

          _logoSelector(),
          const SizedBox(height: 28),

          // ── Datos administrador ────────────────────────────────────────
          if (!_nitYaEnviado) ...[
            _sectionLabel('Datos del Administrador', Icons.person),
            const SizedBox(height: 12),

            _textField(
              controller: _cedulaController,
              label: 'Cédula *',
              icon: Icons.badge,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingrese la cédula';
                if (v.trim().length < 6) return 'Cédula inválida';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _textField(
              controller: _nombreController,
              label: 'Nombre Completo *',
              icon: Icons.person,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingrese el nombre';
                if (v.trim().split(' ').length < 2) {
                  return 'Ingrese nombre y apellido';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            _textField(
              controller: _emailController,
              label: 'Correo Electrónico *',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingrese el correo';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Correo inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Contraseña *',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                hintText: 'Mín. 6 car., 1 mayús., 1 núm., 1 especial',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirmar Contraseña *',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirme la contraseña';
                if (v != _passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),

            _sectionLabel('Firma del Administrador', Icons.draw),
            const SizedBox(height: 12),
            _firmaWidget(),
            const SizedBox(height: 32),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF43CEA2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'Enviar Solicitud',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Widgets helpers ──────────────────────────────────────────────────────

  Widget _bannerEspera(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: Colors.orange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF185A9D), size: 20),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF185A9D))),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: validator,
    );
  }

  Widget _logoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.image, color: Color(0xFF185A9D), size: 20),
            const SizedBox(width: 8),
            const Text('Logo de la Empresa',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF185A9D))),
            const SizedBox(width: 6),
            Text('(opcional)',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: (_subiendoLogo || _nitYaEnviado) ? null : _seleccionarLogo,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              border: Border.all(
                  color: Colors.grey.shade400, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: _subiendoLogo
                ? const Center(child: CircularProgressIndicator())
                : _logoUrl != null
                    ? Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.network(_logoUrl!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: 110),
                        ),
                        Positioned(
                          top: 6, right: 6,
                          child: GestureDetector(
                            onTap: () => setState(() => _logoUrl = null),
                            child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ])
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 36, color: Colors.grey[400]),
                          const SizedBox(height: 6),
                          Text('Toca para seleccionar logo',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 13)),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _firmaWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              _signatureController.clear();
              setState(() => _firmaVacia = false);
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Limpiar'),
            style:
                TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          ),
        ]),
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
            child: Text('La firma es obligatoria',
                style: TextStyle(color: Colors.red[700], fontSize: 12)),
          ),
        const SizedBox(height: 4),
        Text('Dibuje su firma en el recuadro',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}