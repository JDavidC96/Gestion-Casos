// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Colores centralizados de SafeGestion.
/// Cualquier cambio de branding se hace únicamente aquí.
class AppColors {
  AppColors._(); // no instanciable

  // ─── Gradientes principales ──────────────────────────────────────────────
  static const Color primaryPurple     = Color(0xFF6A11CB);
  static const Color primaryBlue       = Color(0xFF2575FC);
  static const Color accentGreen       = Color(0xFF43CEA2);
  static const Color accentNavy        = Color(0xFF185A9D);
  static const Color warmOrangeStart   = Color(0xFFFF512F);
  static const Color warmOrangeEnd     = Color(0xFFF09819);

  // ─── Colores de rol ──────────────────────────────────────────────────────
  static const Color roleSuperAdmin    = Colors.red;
  static const Color roleAdmin         = Colors.orange;
  static const Color roleSuperInspector = Colors.purple;
  static const Color roleInspector     = Colors.blue;

  // ─── Colores de estado ───────────────────────────────────────────────────
  static const Color success           = Colors.green;
  static const Color warning           = Colors.orange;
  static const Color error             = Colors.red;
  static const Color info              = Colors.blue;

  // ─── Niveles de peligro ──────────────────────────────────────────────────
  static const Color riskLow           = Colors.green;
  static const Color riskMedium        = Colors.orange;
  static final Color riskHigh          = Colors.red.shade400;
  static const Color riskNA            = Colors.grey;

  // ─── Acciones / FAB ──────────────────────────────────────────────────────
  static const Color fabPrimary        = Colors.orange;
  static const Color fabConfig         = Colors.green;
  static const Color fabLogo           = Colors.purple;

  // ─── Google Sign-In ──────────────────────────────────────────────────────
  static const Color google            = Color(0xFFDB4437);

  // ─── PDF / Reportes ──────────────────────────────────────────────────────
  static final Color pdfButton         = Colors.red.shade700;
  static final Color shareButton       = Colors.green.shade700;
  static const Color pdfAppBar         = Color(0xFF4F81BD);

  // ─── Gradientes reutilizables ────────────────────────────────────────────
  static const LinearGradient gradientPurpleBlue = LinearGradient(
    colors: [primaryPurple, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientGreenNavy = LinearGradient(
    colors: [accentGreen, accentNavy],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient gradientWarmOrange = LinearGradient(
    colors: [warmOrangeStart, warmOrangeEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Color del rol para avatares y badges.
  static Color colorForRole(String? role) {
    switch (role) {
      case 'super_admin':    return roleSuperAdmin;
      case 'admin':          return roleAdmin;
      case 'superinspector': return roleSuperInspector;
      case 'inspector':      return roleInspector;
      default:               return Colors.grey;
    }
  }

  /// Color del nivel de peligro.
  static Color colorForRiskLevel(String nivel) {
    switch (nivel) {
      case 'Bajo':  return riskLow;
      case 'Medio': return riskMedium;
      case 'Alto':  return riskHigh;
      default:      return riskNA;
    }
  }
}