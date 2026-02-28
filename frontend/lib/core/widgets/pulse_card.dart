import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/pulse_colors.dart';

class PulseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final bool glowEffect;
  final bool glassEffect;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const PulseCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.borderRadius = 24,
    this.glowEffect = false,
    this.glassEffect = false,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: glassEffect ? Colors.transparent : (color ?? PulseColors.surface),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? (glassEffect ? Colors.white.withValues(alpha: 0.2) : PulseColors.border),
          width: 1,
        ),
        boxShadow: shadows ?? (glowEffect ? PulseColors.brandShadow : (glassEffect ? PulseColors.glassShadow : PulseColors.premiumShadow)),
        gradient: glassEffect ? PulseColors.glassGradient : null,
      ),
      child: child,
    );

    if (glassEffect) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: cardContent,
        ),
      );
    }

    if (onTap != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardContent,
        ),
      );
    }

    return Container(
      margin: margin ?? EdgeInsets.zero,
      child: cardContent,
    );
  }
}
