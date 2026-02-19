import 'package:flutter/material.dart';

class PulseColors {
  PulseColors._();

  // Background
  static const Color background = Color(0xFF0F0F1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceVariant = Color(0xFF252540);
  static const Color surfaceLight = Color(0xFF2E2E4A);

  // Primary
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryLight = Color(0xFF9E7BFF);
  static const Color primaryDark = Color(0xFF5C2DC9);

  // Accent
  static const Color accent = Color(0xFF00E5FF);
  static const Color accentDim = Color(0xFF00B8D4);

  // Semantic
  static const Color success = Color(0xFF00E676);
  static const Color successDim = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFAB00);
  static const Color error = Color(0xFFFF5252);
  static const Color errorDim = Color(0xFFD32F2F);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C0);
  static const Color textHint = Color(0xFF6E6E82);
  static const Color textDisabled = Color(0xFF4A4A5E);

  // Border
  static const Color border = Color(0xFF2E2E4A);
  static const Color borderFocused = primary;

  // Misc
  static const Color shimmerBase = Color(0xFF1A1A2E);
  static const Color shimmerHighlight = Color(0xFF2E2E4A);
  static const Color divider = Color(0xFF252540);
  static const Color overlay = Color(0x80000000);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00C853)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
