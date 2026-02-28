import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../services/api_service.dart';
import '../theme/pulse_colors.dart';
import 'dart:async';

// Explicitly import state_notifier if flutter_riverpod is struggling to export it


/// --- 1. Branding State ---
/// Holds all branding-related data for the company.
class BrandingState {
  final String? logoUrl;
  final String? companyName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final List<Color> extractedPalette;
  final bool isLoading;
  
  BrandingState({
    this.logoUrl,
    this.companyName,
    this.primaryColor = const Color(0xFF7C4DFF),
    this.secondaryColor = const Color(0xFF7C4DFF),
    this.accentColor = const Color(0xFF00B8D4),
    this.extractedPalette = const [],
    this.isLoading = false,
  });
  
  BrandingState copyWith({
    String? logoUrl, 
    String? companyName, 
    Color? primaryColor, 
    Color? secondaryColor, 
    Color? accentColor,
    List<Color>? extractedPalette,
    bool? isLoading
  }) {
    return BrandingState(
      logoUrl: logoUrl ?? this.logoUrl,
      companyName: companyName ?? this.companyName,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      extractedPalette: extractedPalette ?? this.extractedPalette,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// --- 2. Branding Notifier ---
/// The logic that handles fetching settings and calculating colors.
class BrandingNotifier extends StateNotifier<BrandingState> {
  BrandingNotifier() : super(BrandingState());

  /// Initial load of branding settings
  Future<void> fetchBranding({String? company}) async {
    state = state.copyWith(isLoading: true);
    try {
      // Use the provided company or fallback to the one in session
      final settings = await ApiService.getSettings(company: company);
      
      String? logo = settings['companyLogo'];
      String? primaryHex = settings['themeColor'];
      String? secondaryHex = settings['secondaryColor'];
      String? accentHex = settings['accentColor'];
      String? name = settings['companyName'];

      Color parseHex(String? hex, Color fallback) {
        if (hex == null || hex.isEmpty) return fallback;
        String h = hex.toUpperCase().replaceAll("#", "");
        if (h.length == 6) h = "FF$h";
        try { return Color(int.parse(h, radix: 16)); } catch (_) { return fallback; }
      }

      final primary = parseHex(primaryHex, const Color(0xFF7C4DFF));
      final secondary = parseHex(secondaryHex, primary);
      final accent = parseHex(accentHex, const Color(0xFF00B8D4));

      List<Color> paletteList = [];

      if (logo != null && logo.isNotEmpty) {
        final palette = await _extractFullPalette(ApiService.getImageUrl(logo));
        paletteList = palette['all'] as List<Color>? ?? [];
        PulseColors.setCompanyBrandPalette(
          primary: primary,
          secondary: secondary,
          accent: accent,
          vibrant: palette['vibrant'],
          muted: palette['muted'],
          light: palette['light'],
          dark: palette['dark'],
        );
      } else {
        PulseColors.setCompanyBrandPalette(primary: primary, secondary: secondary, accent: accent);
      }

      state = state.copyWith(
        logoUrl: logo,
        companyName: name,
        primaryColor: primary,
        secondaryColor: secondary,
        accentColor: accent,
        extractedPalette: paletteList,
        isLoading: false
      );
    } catch (e) {
      debugPrint("Error fetching branding: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  /// Helper to extract multiple colors from a logo URL
  Future<Map<String, dynamic>> _extractFullPalette(String url) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(NetworkImage(url));
      final primary = palette.dominantColor?.color ?? const Color(0xFF7C4DFF);
      
      // Collect all distinct colors for the palette widget
      final List<Color> allColors = palette.colors.toList();

      return {
        'primary': primary,
        'vibrant': palette.vibrantColor?.color ?? primary,
        'muted': palette.mutedColor?.color ?? primary,
        'light': palette.lightVibrantColor?.color ?? palette.lightMutedColor?.color ?? Colors.white,
        'dark': palette.darkVibrantColor?.color ?? palette.darkMutedColor?.color ?? Colors.black,
        'all': allColors,
      };
    } catch (_) {
      return {'primary': const Color(0xFF7C4DFF), 'all': <Color>[]};
    }
  }

  /// Update branding in real-time (called after admin settings change)
  Future<void> updateBranding(String? logo, Color primary, {Color? secondary, Color? accent, String? companyName}) async {
    state = state.copyWith(isLoading: true);
    final sColor = secondary ?? primary;
    final aColor = accent ?? state.accentColor;

    List<Color> paletteList = [];
    if (logo != null && logo.isNotEmpty) {
      final palette = await _extractFullPalette(ApiService.getImageUrl(logo));
      paletteList = palette['all'] as List<Color>? ?? [];
      PulseColors.setCompanyBrandPalette(
        primary: primary,
        secondary: sColor,
        accent: aColor,
        vibrant: palette['vibrant'],
        muted: palette['muted'],
        light: palette['light'],
        dark: palette['dark'],
      );
    } else {
      PulseColors.setCompanyBrandPalette(primary: primary, secondary: sColor, accent: aColor);
    }
    
    state = state.copyWith(
      logoUrl: logo, 
      companyName: companyName ?? state.companyName, 
      primaryColor: primary, 
      secondaryColor: sColor,
      accentColor: aColor,
      extractedPalette: paletteList,
      isLoading: false
    );
  }
}

/// --- 3. The Global Provider ---
final brandingProvider = StateNotifierProvider<BrandingNotifier, BrandingState>((ref) {
  return BrandingNotifier();
});
