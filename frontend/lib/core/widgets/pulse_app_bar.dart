import 'package:flutter/material.dart';
import '../theme/pulse_colors.dart';
import '../theme/pulse_text_styles.dart';
import 'branded_logo.dart';

class PulseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLogo;
  final Widget? leading;

  const PulseAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showLogo = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLogo) ...[
            BrandedLogo(size: 32, showText: false),
            const SizedBox(width: 10),
          ],
          Text(title, style: PulseTextStyles.h3.copyWith(fontSize: 17)),
        ],
      ),
      actions: actions,
      leading: leading,
      backgroundColor: PulseColors.background,
      elevation: 0,
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 0.5,
          color: PulseColors.border.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

