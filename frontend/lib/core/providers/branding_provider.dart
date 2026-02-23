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
  final Color brandColor;
  final bool isLoading;
  
  BrandingState({
    this.logoUrl,
    this.companyName,
    this.brandColor = const Color(0xFF7C4DFF), // Default Pulse Purple
    this.isLoading = false,
  });
  
  BrandingState copyWith({String? logoUrl, String? companyName, Color? brandColor, bool? isLoading}) {
    return BrandingState(
      logoUrl: logoUrl ?? this.logoUrl,
      companyName: companyName ?? this.companyName,
      brandColor: brandColor ?? this.brandColor,
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
      String? hex = settings['themeColor'];
      String? name = settings['companyName'];
      
      if (hex != null && hex.isNotEmpty) {
        hex = hex.toUpperCase().replaceAll("#", "");
        if (hex.length == 6) hex = "FF$hex";
        final color = Color(int.parse(hex, radix: 16));
        
        // Extract rest of palette if possible, otherwise just primary
        if (logo != null && logo.isNotEmpty) {
          final palette = await _extractFullPalette(ApiService.getImageUrl(logo));
          PulseColors.setCompanyBrandPalette(
            primary: color,
            vibrant: palette['vibrant'],
            muted: palette['muted'],
            light: palette['light'],
            dark: palette['dark'],
          );
        } else {
          PulseColors.setCompanyBrandPalette(primary: color);
        }
        
        state = state.copyWith(logoUrl: logo, companyName: name, brandColor: color, isLoading: false);
      } else if (logo != null && logo.isNotEmpty) {
        final palette = await _extractFullPalette(ApiService.getImageUrl(logo));
        PulseColors.setCompanyBrandPalette(
          primary: palette['primary']!,
          vibrant: palette['vibrant'],
          muted: palette['muted'],
          light: palette['light'],
          dark: palette['dark'],
        );
        state = state.copyWith(
          logoUrl: logo,
          companyName: name,
          brandColor: palette['primary']!,
          isLoading: false,
        );
      } else {
        state = state.copyWith(companyName: name, isLoading: false);
      }
    } catch (e) {
      debugPrint("Error fetching branding: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  /// Helper to extract multiple colors from a logo URL
  Future<Map<String, Color>> _extractFullPalette(String url) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(NetworkImage(url));
      final primary = palette.dominantColor?.color ?? const Color(0xFF7C4DFF);
      return {
        'primary': primary,
        'vibrant': palette.vibrantColor?.color ?? primary,
        'muted': palette.mutedColor?.color ?? primary,
        'light': palette.lightVibrantColor?.color ?? palette.lightMutedColor?.color ?? Colors.white,
        'dark': palette.darkVibrantColor?.color ?? palette.darkMutedColor?.color ?? Colors.black,
      };
    } catch (_) {
      return {'primary': const Color(0xFF7C4DFF)};
    }
  }

  /// Update branding in real-time (called after admin settings change)
  Future<void> updateBranding(String? logo, Color color, {String? companyName}) async {
    state = state.copyWith(isLoading: true);
    if (logo != null && logo.isNotEmpty) {
      final palette = await _extractFullPalette(ApiService.getImageUrl(logo));
      PulseColors.setCompanyBrandPalette(
        primary: color,
        vibrant: palette['vibrant'],
        muted: palette['muted'],
        light: palette['light'],
        dark: palette['dark'],
      );
    } else {
      PulseColors.setCompanyBrandPalette(primary: color);
    }
    state = state.copyWith(
      logoUrl: logo, 
      companyName: companyName ?? state.companyName, 
      brandColor: color, 
      isLoading: false
    );
  }
}

/// --- 3. The Global Provider ---
final brandingProvider = StateNotifierProvider<BrandingNotifier, BrandingState>((ref) {
  return BrandingNotifier();
});
