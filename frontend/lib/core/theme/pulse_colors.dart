import 'package:flutter/material.dart';

class PulseColors {
  PulseColors._();

  // Dynamic Brand Palette
  static Color _brandPrimary = const Color(0xFF7C4DFF);
  static Color _brandVibrant = const Color(0xFF7C4DFF);
  static Color _brandMuted = const Color(0xFF7C4DFF);
  static Color _brandLight = const Color(0xFFF0E6FF);
  static Color _brandDark = const Color(0xFF5C2DC9);

  // Method to inject the full company branding palette
  static void setCompanyBrandPalette({
    required Color primary,
    Color? vibrant,
    Color? muted,
    Color? light,
    Color? dark,
  }) {
    _brandPrimary = primary;
    _brandVibrant = vibrant ?? primary;
    _brandMuted = muted ?? Color.lerp(primary, Colors.grey.shade400, 0.4) ?? primary;
    // Premium Light: A very subtle tint for surfaces, avoiding pure white
    _brandLight = light ?? Color.lerp(primary, Colors.white, 0.94) ?? primary;
    // Professional Dark: Deep, rich tones for contrast
    _brandDark = dark ?? Color.lerp(primary, Colors.black, 0.7) ?? primary;
  }

  // Compatibility alias for single color injection
  static void setCompanyBrandColor(Color color) {
    setCompanyBrandPalette(primary: color);
  }

  // Background
  static const Color background = Color(0xFFF8F9FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Primary (Now Dynamic)
  static Color get brandPrimary => _brandPrimary;
  static Color get primary => _brandPrimary;
  static Color get brandVibrant => _brandVibrant;
  static Color get brandMuted => _brandMuted;
  static Color get brandLight => _brandLight;
  static Color get primaryLight => _brandLight; // Compatibility alias
  static Color get primaryDark => _brandDark;

  // Accent
  static const Color accent = Color(0xFF00B8D4);
  static const Color accentDim = Color(0xFF0097A7);

  // Semantic
  static const Color success = Color(0xFF00C853);
  static const Color successDim = Color(0xFF1B5E20);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorDim = Color(0xFFB71C1C);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFFCBD5E1);

  // Border
  static const Color border = Color(0xFFE2E8F0);
  static Color get borderFocused => _brandPrimary;

  // Misc
  static const Color shimmerBase = Color(0xFFF1F5F9);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);
  static const Color divider = Color(0xFFEDF2F7);
  static const Color overlay = Color(0x66000000);

  // --- Advanced Brand Utilities ---
  static LinearGradient get brandGradient => LinearGradient(
    colors: [_brandPrimary, _brandVibrant],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get glassGradient => LinearGradient(
    colors: [
      Colors.white.withOpacity(0.15),
      Colors.white.withOpacity(0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Soft Layered Shadow (Modern Premium Style)
  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: _brandPrimary.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 10),
      spreadRadius: -5,
    ),
  ];

  static List<BoxShadow> get brandShadow => [
    BoxShadow(
      color: _brandPrimary.withOpacity(0.15),
      blurRadius: 24,
      offset: const Offset(0, 12),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> get brandGlow => [
    BoxShadow(
      color: _brandPrimary.withOpacity(0.25),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  // Gradients (Updated for Light Mode)
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [_brandPrimary, _brandVibrant],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00B8D4), Color(0xFF0097A7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF1B5E20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF8F9FD), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
