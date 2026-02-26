import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pulse_colors.dart';

class PulseTextStyles {
  PulseTextStyles._();

  static TextStyle get h1 => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: PulseColors.textPrimary,
    letterSpacing: -1.0,
    height: 1.1,
  );

  static TextStyle get h2 => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: PulseColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get h3 => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: PulseColors.textPrimary,
    height: 1.3,
  );

  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: PulseColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get bodyBold => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: PulseColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: PulseColors.textHint,
    height: 1.4,
  );

  static TextStyle get captionBold => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: PulseColors.textSecondary,
    height: 1.4,
  );

  static TextStyle get button => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: PulseColors.textSecondary,
    height: 1.4,
  );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: PulseColors.textPrimary,
    letterSpacing: 2,
  );

  static TextStyle get chip => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static TextStyle get badge => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}
