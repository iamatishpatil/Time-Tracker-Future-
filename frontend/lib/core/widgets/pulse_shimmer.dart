import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/pulse_colors.dart';

class PulseShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const PulseShimmer({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: PulseColors.shimmerBase,
      highlightColor: PulseColors.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: PulseColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Card-shaped shimmer placeholder
  static Widget card({double height = 120}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PulseShimmer(height: height, borderRadius: 20),
    );
  }

  /// List of shimmer cards
  static Widget list({int count = 4, double itemHeight = 80}) {
    return Column(
      children: List.generate(
        count,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PulseShimmer(height: itemHeight, borderRadius: 20),
        ),
      ),
    );
  }

  /// Grid shimmer for dashboard stats
  static Widget grid({int count = 4}) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: List.generate(count, (_) => const PulseShimmer(height: 100, borderRadius: 20)),
    );
  }
}
