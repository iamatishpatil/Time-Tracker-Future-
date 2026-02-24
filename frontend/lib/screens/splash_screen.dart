import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/providers/branding_provider.dart';
import '../core/theme/pulse_colors.dart';
import '../core/widgets/pulse_scaffold.dart';
import '../services/api_service.dart';
import 'admin/admin_container.dart';
import 'main_container.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await ref.read(brandingProvider.notifier).fetchBranding().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Branding initialization failed: $e");
    }
    
    final user = await ApiService.getStoredUser();
    
    if (user != null && user['company'] != null) {
      try {
        await ref.read(brandingProvider.notifier).fetchBranding(company: user['company']);
      } catch (_) {}
    }
    
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

    return PulseScaffold(
      showLogoInBar: false,
      useBrandedBackground: true, 
      brandVibrant: true,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Company Logo ---
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: PulseColors.primary.withOpacity(0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: PulseColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? Image.network(
                        ApiService.getImageUrl(logoUrl),
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        ),
                      )
                    : Image.asset(
                        'assets/icon.png',
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                      ),
              ),
            )
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut),
            
            const SizedBox(height: 24),
            
            // --- TIME TRACKER Text ---
            Text(
              'TIME TRACKER',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: PulseColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
            
            const SizedBox(height: 8),
            
            // --- Tagline ---
            Text(
              'Manage Time Effortlessly',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PulseColors.primary,
                letterSpacing: 2.0,
              ),
            ).animate().fadeIn(delay: 800.ms),
            
            const SizedBox(height: 80), 
            
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 2),
            ).animate().fadeIn(delay: 1500.ms),
          ],
        ),
      ),
    );
  }
}
