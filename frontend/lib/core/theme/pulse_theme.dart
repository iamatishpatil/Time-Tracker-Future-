import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pulse_colors.dart';

class PulseTheme {
  PulseTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: ColorScheme.light(
        primary: PulseColors.primary,
        onPrimary: PulseColors.onPrimary,
        secondary: PulseColors.secondary,
        onSecondary: PulseColors.onSecondary,
        tertiary: PulseColors.accent,
        onTertiary: PulseColors.onAccent,
        surface: PulseColors.surface,
        onSurface: PulseColors.textPrimary,
        primaryContainer: PulseColors.primaryContainer,
        secondaryContainer: PulseColors.secondaryContainer,
        error: PulseColors.error,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: PulseColors.background,

      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: PulseColors.textPrimary,
        displayColor: PulseColors.textPrimary,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: PulseColors.surface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        surfaceTintColor: PulseColors.primary.withValues(alpha: 0.05),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.outfit(
          color: PulseColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: PulseColors.textPrimary,
          size: 22,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: PulseColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: PulseColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PulseColors.primary,
          foregroundColor: PulseColors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.1)),
        ),
      ),

      // Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PulseColors.secondary,
          side: BorderSide(color: PulseColors.secondary.withValues(alpha: 0.5), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PulseColors.primary.withValues(alpha: 0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: PulseColors.primary.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: PulseColors.primary.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: PulseColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: PulseColors.error),
        ),
        labelStyle: GoogleFonts.inter(color: PulseColors.textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: PulseColors.textHint, fontSize: 14),
        prefixIconColor: PulseColors.primary.withValues(alpha: 0.6),
        suffixIconColor: PulseColors.primary.withValues(alpha: 0.6),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: PulseColors.surface,
        selectedItemColor: PulseColors.primary,
        unselectedItemColor: PulseColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        enableFeedback: true,
      ),

      // Drawer
      drawerTheme: DrawerThemeData(
        backgroundColor: PulseColors.surface,
        surfaceTintColor: PulseColors.primary.withValues(alpha: 0.05),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),

      // ProgressIndicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: PulseColors.primary,
        linearTrackColor: PulseColors.primary.withValues(alpha: 0.1),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: PulseColors.primary.withValues(alpha: 0.08),
        selectedColor: PulseColors.primary,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: PulseColors.primary,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),

      // Page Transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: PulseColors.primary,
        foregroundColor: PulseColors.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: PulseColors.divider,
        thickness: 1,
        space: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PulseColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),

      // Segmented Button
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: PulseColors.primary,
          selectedForegroundColor: PulseColors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: PulseColors.primary,
        unselectedLabelColor: PulseColors.textSecondary,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: PulseColors.primary),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PulseColors.surface,
        elevation: 10,
        modalBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        iconColor: PulseColors.primary.withValues(alpha: 0.7),
        textColor: PulseColors.textPrimary,
        titleTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        subtitleTextStyle: GoogleFonts.inter(color: PulseColors.textSecondary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),

      // Icon
      iconTheme: IconThemeData(
        color: PulseColors.primary.withValues(alpha: 0.8),
        size: 24,
      ),
    );
  }
}
