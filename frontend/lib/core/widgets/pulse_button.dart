import 'package:flutter/material.dart';
import '../theme/pulse_colors.dart';
import '../theme/pulse_text_styles.dart';

enum PulseButtonVariant { primary, secondary, outline, danger, success }

class PulseButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final PulseButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final double width;
  final double height;

  const PulseButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = PulseButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.width = double.infinity,
    this.height = 56,
  });

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LinearGradient get _gradient {
    switch (widget.variant) {
      case PulseButtonVariant.primary:
        return PulseColors.primaryGradient;
      case PulseButtonVariant.success:
        return PulseColors.successGradient;
      case PulseButtonVariant.danger:
        return PulseColors.errorGradient;
      default:
        return PulseColors.primaryGradient;
    }
  }

  bool get _isFilled =>
      widget.variant == PulseButtonVariant.primary ||
      widget.variant == PulseButtonVariant.success ||
      widget.variant == PulseButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _controller.forward(),
      onTapUp: isDisabled ? null : (_) => _controller.reverse(),
      onTapCancel: isDisabled ? null : () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: _isFilled && !isDisabled ? _gradient : null,
            color: _isFilled
                ? (isDisabled ? PulseColors.surfaceVariant : null)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: !_isFilled
                ? Border.all(
                    color: widget.variant == PulseButtonVariant.outline
                        ? PulseColors.border
                        : PulseColors.primary,
                    width: 1.5,
                  )
                : null,
            boxShadow: _isFilled && !isDisabled
                ? [
                    BoxShadow(
                      color: PulseColors.brandPrimary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled ? null : widget.onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              size: 20,
                              color: _isFilled
                                  ? Colors.white
                                  : PulseColors.primary,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.text,
                            style: PulseTextStyles.button.copyWith(
                              color: _isFilled
                                  ? (isDisabled
                                      ? PulseColors.textHint
                                      : Colors.white)
                                  : PulseColors.primary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
