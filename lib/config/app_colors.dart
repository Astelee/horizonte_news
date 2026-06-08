import 'package:flutter/material.dart';

class AppColors {
  // ── Identidade Principal ─────────────────────────────────────────────────
  static const Color primaryOrange      = Color(0xFFFF6B00);
  static const Color primaryOrangeLight = Color(0xFFFF8C3A);
  static const Color primaryOrangeDark  = Color(0xFFCC4400);
  static const Color accentOrange       = Color(0xFFF57C00);

  // ── Compatibilidade total com código existente ───────────────────────────
  static const Color primaryBlue = primaryOrange;
  static const Color accentBlue  = accentOrange;

  // ── Alertas ──────────────────────────────────────────────────────────────
  static const Color emergencyRed = Color(0xFFE53935);

  // ── Fundos ───────────────────────────────────────────────────────────────
  static const Color backgroundDark     = Color(0xFF000000);
  static const Color backgroundCard     = Color(0xFF0F0F0F);
  static const Color backgroundElevated = Color(0xFF1A1A1A);
  static const Color backgroundLight    = Color(0xFFF8F9FA);
  static const Color surfaceLight       = Color(0xFFFFFFFF);
  static const Color surfaceDark        = Color(0xFF141414);

  // ── Bordas ───────────────────────────────────────────────────────────────
  static const Color borderLight  = Color(0xFFD1D1D1);
  static const Color borderDark   = Color(0xFF222222);
  static const Color borderGlow   = Color(0x33FF6B00);
  static const Color borderOrange = Color(0x66FF6B00);
  static const Color borderSubtle = Color(0xFF1E1E1E);

  // ── Textos ───────────────────────────────────────────────────────────────
  static const Color textPrimary        = Color(0xFFFFFFFF);
  static const Color textSecondary      = Color(0xFFAAAAAA);
  static const Color textMuted          = Color(0xFF555555);
  static const Color textOrange         = Color(0xFFFF6B00);
  static const Color textPrimaryLight   = Color(0xFF121212);
  static const Color textPrimaryDark    = Color(0xFFFFFFFF);
  static const Color textSecondaryLight = Color(0xFF575757);
  static const Color textSecondaryDark  = Color(0xFFB0B0B0);
  static const Color whiteFaded         = Colors.white70;

  // ── Gradientes ───────────────────────────────────────────────────────────
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF6B00), Color(0xFFFF8C3A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient orangeVertical = LinearGradient(
    colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xD9000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient drawerGradient = LinearGradient(
    colors: [Color(0xFF100800), Color(0xFF000000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient glowOrange = RadialGradient(
    colors: [Color(0x55FF6B00), Color(0x00FF6B00)],
    radius: 0.9,
  );
}
