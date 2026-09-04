import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/pulse_colors.dart';
import '../theme/pulse_text_styles.dart';

class PulseEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PulseEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    PulseColors.primary.withOpacity(0.08),
                    PulseColors.brandVibrant.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: PulseColors.primary.withOpacity(0.15),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: PulseColors.primary.withOpacity(0.08),
                    blurRadius: 24,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(icon, size: 44, color: PulseColors.primary.withOpacity(0.5)),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.8, 0.8), duration: 500.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 28),
            Text(title, style: PulseTextStyles.h3, textAlign: TextAlign.center)
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.15),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: PulseTextStyles.body.copyWith(height: 1.6),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
            ],
          ],
        ),
      ),
    );
  }
}

