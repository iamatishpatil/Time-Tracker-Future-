import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/branding_provider.dart';
import '../theme/pulse_colors.dart';
import 'package:frontend/core/services/api_service.dart';

class BrandedBackground extends ConsumerWidget {
  final Widget? child;

  const BrandedBackground({super.key, this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingProvider);
    final logoUrl = branding.logoUrl;

    return Stack(
      // Ensure there is always an opaque background — prevents black screen on emulator
      // when the theme hasn't been applied yet or the scaffold background is transparent.
      children: [
        // Solid base background
        Positioned.fill(
          child: ColoredBox(color: PulseColors.background),
        ),
        // The Watermark
        logoUrl != null && logoUrl.isNotEmpty
            ? Positioned.fill(
                child: Opacity(
                  opacity: 0.03, // Extremely subtle
                  child: Center(
                    child: Image.network(
                      ApiService.getImageUrl(logoUrl),
                      width: MediaQuery.of(context).size.width * 0.7,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              )
            : Positioned.fill(
                child: Opacity(
                  opacity: 0.02, // Even more subtle for text
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.2, // Slight tilt for professional look
                      child: Text(
                        (branding.companyName ?? 'TT')
                            .split(' ')
                            .map((e) => e.isNotEmpty ? e[0] : '')
                            .take(2)
                            .join()
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 200,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        
        // The Content
        if (child != null) child!,
      ],
    );
  }
}
