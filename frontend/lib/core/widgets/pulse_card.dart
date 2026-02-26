import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/pulse_colors.dart';

class PulseCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final bool glowEffect;
  final bool glassEffect;
  final bool useEntranceAnimation;

  const PulseCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.onTap,
    this.color,
    this.borderColor,
    this.glowEffect = false,
    this.glassEffect = false,
    this.useEntranceAnimation = true,
  });

  @override
  State<PulseCard> createState() => _PulseCardState();
}

class _PulseCardState extends State<PulseCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.useEntranceAnimation) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: widget.margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: widget.color ?? (widget.glassEffect ? Colors.white.withOpacity(0.7) : PulseColors.surface),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: widget.borderColor ?? PulseColors.border.withOpacity(0.4),
          width: 0.8,
        ),
        boxShadow: widget.glowEffect
            ? PulseColors.brandGlow
            : PulseColors.premiumShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: widget.glassEffect 
              ? ImageFilter.blur(sigmaX: 10, sigmaY: 10) 
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Material(
            color: Colors.transparent,
            child: widget.onTap != null
                ? InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    splashColor: PulseColors.primary.withOpacity(0.08),
                    highlightColor: PulseColors.primary.withOpacity(0.04),
                    child: Padding(
                      padding: widget.padding ?? const EdgeInsets.all(20),
                      child: widget.child,
                    ),
                  )
                : Padding(
                    padding: widget.padding ?? const EdgeInsets.all(20),
                    child: widget.child,
                  ),
          ),
        ),
      ),
    );

    if (widget.useEntranceAnimation) {
      card = FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: card,
        ),
      );
    }

    return card;
  }
}

