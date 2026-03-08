import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginSuccessAnimation extends StatefulWidget {
  const LoginSuccessAnimation({super.key});

  @override
  State<LoginSuccessAnimation> createState() => _LoginSuccessAnimationState();
}

class _LoginSuccessAnimationState extends State<LoginSuccessAnimation>
    with TickerProviderStateMixin {

  late AnimationController logoController;
  late AnimationController ringController;
  late AnimationController particlesController;
  late AnimationController textController;

  late Animation<double> logoScale;
  late Animation<double> ringScale;
  late Animation<double> textOpacity;

  @override
  void initState() {
    super.initState();

    logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    logoScale = CurvedAnimation(
      parent: logoController,
      curve: Curves.elasticOut,
    );

    ringScale = CurvedAnimation(
      parent: ringController,
      curve: Curves.easeOut,
    );

    textOpacity = CurvedAnimation(
      parent: textController,
      curve: Curves.easeIn,
    );

    startAnimation();
  }

  void startAnimation() async {
    logoController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    ringController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    particlesController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    textController.forward();

    // Esperar mínimo para que se vea el splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Si Firebase todavía no respondió, esperar un poco más
    if (authProvider.isCheckingAuth) {
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) return;

    // Redirigir según el estado real de la sesión
    if (authProvider.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    logoController.dispose();
    ringController.dispose();
    particlesController.dispose();
    textController.dispose();
    super.dispose();
  }

  Widget buildParticle(double angle) {
    return AnimatedBuilder(
      animation: particlesController,
      builder: (context, child) {
        final progress = particlesController.value;
        final distance = progress * 120;
        final dx = cos(angle) * distance;
        final dy = sin(angle) * distance;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: 1 - progress,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF000000),
              Color(0xFF0A0A0A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [

              ScaleTransition(
                scale: ringScale,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.orange.withOpacity(.4),
                      width: 2,
                    ),
                  ),
                ),
              ),

              ...List.generate(
                12,
                (i) => buildParticle(i * (pi / 6)),
              ),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  ScaleTransition(
                    scale: logoScale,
                    child: Image.asset(
                      'assets/images/SafeGestionLogo.png',
                      width: 200,
                    ),
                  ),

                  const SizedBox(height: 30),

                  FadeTransition(
                    opacity: textOpacity,
                    child: const Text(
                      "SafeGestion",
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  FadeTransition(
                    opacity: textOpacity,
                    child: const Text(
                      "Sistema de Riesgos Laborales",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  FadeTransition(
                    opacity: textOpacity,
                    child: const SizedBox(
                      width: 180,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: Colors.orange,
                        backgroundColor: Colors.white24,
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
}