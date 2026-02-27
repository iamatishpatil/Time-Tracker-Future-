import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/providers/branding_provider.dart';
import '../core/theme/pulse_colors.dart';
import '../core/widgets/pulse_scaffold.dart';
import '../services/api_service.dart';
import 'admin/admin_container.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _brandingLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load branding for any previously logged-in user first
    final user = await ApiService.getStoredUser();

    try {
      final company = user?['company'];
      await ref
          .read(brandingProvider.notifier)
          .fetchBranding(company: company)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Branding initialization failed: $e");
    }

    // Mark branding as loaded — now show the splash content
    if (mounted) setState(() => _brandingLoaded = true);

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (user != null) {
      if (user['role'] == 'Admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminContainer()),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider);
    final logoUrl = branding.logoUrl;

    // Show plain white while branding is loading — NO app icon flash
    if (!_brandingLoaded) {
      return const Scaffold(backgroundColor: Colors.white);
    }

    return PulseScaffold(
      showLogoInBar: false,
      useBrandedBackground: true,
      brandVibrant: true,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Company Logo (or app icon fallback) ---
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: PulseColors.primary.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: PulseColors.primary.withOpacity(0.25),
                    blurRadius: 28,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ClipOval(
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? Image.network(
                        ApiService.getImageUrl(logoUrl),
                        fit: BoxFit.cover,
                        width: 130,
                        height: 130,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset('assets/icon.png', fit: BoxFit.cover),
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut),

            const SizedBox(height: 28),

            // --- App Name ---
            Text(
              'TIME TRACKER',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: PulseColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

            const SizedBox(height: 8),

            // --- Tagline ---
            Text(
              'Manage Time Effortlessly',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PulseColors.primary,
                letterSpacing: 1.8,
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
