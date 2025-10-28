import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
  body: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF43CEA2), Color(0xFF185A9D)], // verde menta → azul
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.account_circle,
                size: 100,
                color: Colors.white, //  cambiado a blanco para contraste
              ),
              const SizedBox(height: 20),
              const Text(
                "Gestión de Casos",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, //  título en blanco
                ),
              ),
              const SizedBox(height: 40),

              // Campo de correo/usuario
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Correo o Usuario",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 20),

              // Campo de contraseña
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Contraseña",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 10),

              // Botón de "Olvidaste tu contraseña"
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Funcionalidad no implementada"),
                    ),
                  );
                },
                child: const Text(
                  "¿Olvidaste tu contraseña?",
                  style: TextStyle(color: Colors.white), //  texto en blanco
                ),
              ),
              const SizedBox(height: 20),

              // Botón de login
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.deepPurple, // contraste
                ),
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: const Text(
                  "Ingresar",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

  }
}
