// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    // Pequeña pausa para mostrar el splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (authProvider.isAuthenticated) {
        // Usuario autenticado, ahora sí puede consultar Firestore
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .limit(1)
            .get();

        if (usersSnapshot.docs.isEmpty) {
          // No hay usuarios registrados en la base
          Navigator.pushReplacementNamed(context, '/setup');
        } else {
          // Hay usuarios y el actual está autenticado
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // No autenticado, enviar directamente al login
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      // Si ocurre un error (como permisos denegados), va al login
      debugPrint('Error al verificar Firestore: $e');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.business_center,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                "Gestión de Casos",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Sistema de Riesgos Laborales",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 48),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
