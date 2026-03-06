import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/pulse_text_styles.dart';
import '../theme/pulse_colors.dart';

class PulseClock extends StatefulWidget {
  final bool detailed;
  final bool showDate;
  final String datePattern;
  final TextStyle? timeStyle;
  final TextStyle? dateStyle;

  const PulseClock({
    super.key,
    this.detailed = false,
    this.showDate = true,
    this.datePattern = 'EEEE, MMMM d',
    this.timeStyle,
    this.dateStyle,
  });

  @override
  State<PulseClock> createState() => _PulseClockState();
}

class _PulseClockState extends State<PulseClock> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.detailed) {
      return _buildDetailed();
    }
    return _buildSimple();
  }

  Widget _buildSimple() {
    final timeStr = DateFormat('hh:mm:ss a').format(_now);
    final dateStr = DateFormat(widget.datePattern).format(_now);
    return Column(
      children: [
        Text(
          timeStr,
          style: widget.timeStyle ?? PulseTextStyles.h1.copyWith(fontSize: 42, letterSpacing: -1, color: PulseColors.brandPrimary),
        ),
        if (widget.showDate) ...[
          const SizedBox(height: 8),
          Text(
            dateStr,
            style: widget.dateStyle ?? PulseTextStyles.body.copyWith(color: PulseColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailed() {
    final timeStr = DateFormat('hh:mm:ss a').format(_now);
    final dateStr = DateFormat(widget.datePattern).format(_now).toUpperCase();
    
    final parts = timeStr.split(' ');
    if (parts.length < 2) return Text(timeStr);

    final String timePart = parts[0];
    final String ampm = parts[1];
    final tp = timePart.split(':');
    if (tp.length < 3) return Text(timeStr);

    return Column(
      children: [
        RichText(
          text: TextSpan(
            style: PulseTextStyles.mono.copyWith(fontSize: 52, letterSpacing: -2),
            children: [
              TextSpan(text: tp[0], style: const TextStyle(fontWeight: FontWeight.w900, color: PulseColors.textPrimary)),
              TextSpan(text: ':', style: TextStyle(color: PulseColors.primary.withValues(alpha: 0.3))),
              TextSpan(text: tp[1], style: const TextStyle(fontWeight: FontWeight.w700, color: PulseColors.textSecondary)),
              TextSpan(text: ':', style: TextStyle(color: PulseColors.primary.withValues(alpha: 0.3))),
              TextSpan(text: tp[2], style: const TextStyle(fontWeight: FontWeight.w200, color: PulseColors.textHint, fontSize: 36)),
              const TextSpan(text: ' '),
              TextSpan(text: ampm, style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primary, fontSize: 16, letterSpacing: 0)),
            ],
          ),
        ),
        if (widget.showDate) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: PulseColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              dateStr,
              style: PulseTextStyles.captionBold.copyWith(letterSpacing: 2.5, fontSize: 10, color: PulseColors.primary),
            ),
          ),
        ],
      ],
    );
  }
}
