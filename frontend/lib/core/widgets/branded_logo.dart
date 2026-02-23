import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/branding_provider.dart';
import '../theme/pulse_colors.dart';
import '../theme/pulse_text_styles.dart';
import '../../services/api_service.dart';

class BrandedLogo extends ConsumerWidget {
  final double size;
  final bool showText;
  // removed shadowing animate property

  const BrandedLogo({
    super.key,
    this.size = 60,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingProvider);
    final logoUrl = branding.logoUrl;
    final companyName = branding.companyName ?? 'TIME TRACKER';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogoImage(context, logoUrl, companyName),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            companyName.toUpperCase(),
            textAlign: TextAlign.center,
            style: PulseTextStyles.h1.copyWith(
              fontSize: size * 0.35,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: PulseColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLogoImage(BuildContext context, String? logoUrl, String companyName) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.1), // Reduced padding for better fit
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PulseColors.surface,
        border: Border.all(color: PulseColors.primary.withOpacity(0.4), width: 1.5),
        boxShadow: PulseColors.brandShadow,
      ),
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                ApiService.getImageUrl(logoUrl),
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Shimmer.fromColors(
                    baseColor: PulseColors.shimmerBase,
                    highlightColor: PulseColors.shimmerHighlight,
                    child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  );
                },
                errorBuilder: (context, error, stackTrace) => _buildFallback(companyName),
              ),
            )
          : _buildFallback(companyName),
    );
  }

  Widget _buildFallback(String companyName) {
    final initials = companyName.isNotEmpty 
        ? companyName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'TT';

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: PulseColors.brandGradient,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.3,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
