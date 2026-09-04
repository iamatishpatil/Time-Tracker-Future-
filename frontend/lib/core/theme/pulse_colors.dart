import 'package:flutter/material.dart';

class PulseColors {
  PulseColors._();

  // Dynamic Brand Palette
  static Color _brandPrimary = const Color(0xFF7C4DFF);
  static Color _brandSecondary = const Color(0xFF7C4DFF);
  static Color _brandAccent = const Color(0xFF00B8D4);
  static Color _brandVibrant = const Color(0xFF7C4DFF);
  static Color _brandMuted = const Color(0xFF7C4DFF);
  static Color _brandLight = const Color(0xFFF0E6FF);
  static Color _brandDark = const Color(0xFF5C2DC9);

  // Method to inject the full company branding palette
  static void setCompanyBrandPalette({
    required Color primary,
    Color? secondary,
    Color? accent,
    Color? vibrant,
    Color? muted,
    Color? light,
    Color? dark,
  }) {
    _brandPrimary = primary;
    _brandSecondary = secondary ?? primary;
    _brandAccent = accent ?? const Color(0xFF00B8D4);
    _brandVibrant = vibrant ?? primary;
    _brandMuted = muted ?? Color.lerp(primary, Colors.grey.shade400, 0.4) ?? primary;
    _brandLight = light ?? Color.lerp(primary, Colors.white, 0.94) ?? primary;
    _brandDark = dark ?? Color.lerp(primary, Colors.black, 0.7) ?? primary;
  }

  // Compatibility alias for single color injection
  static void setCompanyBrandColor(Color color) {
    setCompanyBrandPalette(primary: color);
  }

  // Contrast-Aware Colors (Calculated)
  static Color get onPrimary => _brandPrimary.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  static Color get onSecondary => _brandSecondary.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  static Color get onAccent => _brandAccent.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  static Color get onVibrant => _brandVibrant.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  static Color get primaryContainer => _brandPrimary.withOpacity(0.08);
  static Color get secondaryContainer => _brandSecondary.withOpacity(0.08);
  
  // Background & Surface
  static const Color background = Color(0xFFF8F9FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Dynamic Getters
  static Color get primary => _brandPrimary;
  static Color get secondary => _brandSecondary;
  static Color get accent => _brandAccent;
  static Color get vibrant => _brandVibrant;
  static Color get muted => _brandMuted;
  static Color get light => _brandLight;
  static Color get dark => _brandDark;

  // Semantic
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFD32F2F);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFFCBD5E1);

  // Border
  static const Color border = Color(0xFFE2E8F0);
  static Color get borderFocused => _brandPrimary;

  // Shimmer
  static const Color shimmerBase = Color(0xFFF1F5F9);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);

  // Misc
  static const Color divider = Color(0xFFEDF2F7);
  static const Color overlay = Color(0x66000000);

  // --- Premium UI Extensions ---
  
  // Advanced Gradients
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [_brandPrimary, _brandVibrant, _brandPrimary.withOpacity(0.8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: const [0.0, 0.5, 1.0],
  );

  static LinearGradient get meshGradient => LinearGradient(
    colors: [
      _brandPrimary.withOpacity(0.15),
      _brandAccent.withOpacity(0.1),
      _brandPrimary.withOpacity(0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get glassGradient => LinearGradient(
    colors: [
      Colors.white.withOpacity(0.2),
      Colors.white.withOpacity(0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get surfaceGradient => LinearGradient(
    colors: [Colors.white, _brandPrimary.withOpacity(0.02)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get drawerGradient => LinearGradient(
    colors: [_brandPrimary, _brandPrimary.withOpacity(0.85)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Compatibility Gradients
  static LinearGradient get brandGradient => primaryGradient;
  static LinearGradient get successGradient => const LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF1B5E20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient get errorGradient => const LinearGradient(
    colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Modern Shadows
  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: _brandPrimary.withOpacity(0.05),
      blurRadius: 20,
      offset: const Offset(0, 10),
      spreadRadius: -2,
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
      color: _brandPrimary.withOpacity(0.3),
      blurRadius: 15,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> get glassShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // --- Compatibility Aliases ---
  static Color get brandPrimary => _brandPrimary;
  static Color get brandSecondary => _brandSecondary;
  static Color get brandAccent => _brandAccent;
  static Color get brandVibrant => _brandVibrant;
  static Color get brandMuted => _brandMuted;
  static Color get brandLight => _brandLight;
  static Color get primaryLight => _brandLight;
  static Color get primaryDark => _brandDark;
}
