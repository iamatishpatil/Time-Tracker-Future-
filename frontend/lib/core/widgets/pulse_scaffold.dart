import 'package:flutter/material.dart';
import '../theme/pulse_colors.dart';
import 'branded_background.dart';
import 'pulse_app_bar.dart';

class PulseScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final List<Widget>? actions;
  final bool useBrandedBackground;
  final bool brandVibrant;
  final bool showLogoInBar;
  final Widget? bottomNavigationBar;

  const PulseScaffold({
    super.key,
    this.title,
    required this.body,
    this.floatingActionButton,
    this.drawer,
    this.actions,
    this.showLogoInBar = true,
    this.bottomNavigationBar,
    this.useBrandedBackground = true,
    this.brandVibrant = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? PulseAppBar(
              title: title!,
              actions: actions,
              showLogo: showLogoInBar,
            )
          : null,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: useBrandedBackground
          ? BrandedBackground(child: body)
          : body,
      backgroundColor: brandVibrant ? PulseColors.brandLight.withValues(alpha: 0.5) : null,
    );
  }
}
