import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/providers/branding_provider.dart';
import '../core/theme/pulse_colors.dart';
import '../core/widgets/pulse_scaffold.dart';
import '../core/widgets/branded_logo.dart';
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
    // 1. Fetch Branding (with safety timeout)
    try {
      await ref.read(brandingProvider.notifier).fetchBranding().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Branding initialization failed: $e");
    }
    
    // 2. Check Session
    final user = await ApiService.getStoredUser();
    
    // 3. If user is found, re-fetch branding with THEIR company to be sure
    if (user != null && user['company'] != null) {
      try {
        await ref.read(brandingProvider.notifier).fetchBranding(company: user['company']);
      } catch (_) {}
    }
    
    // 4. Small delay for effect
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
    return PulseScaffold(
      showLogoInBar: false,
      useBrandedBackground: true, 
      brandVibrant: true,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- 1. The Dynamic Logo & Name ---
            BrandedLogo(size: 100)
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut),
            
            const SizedBox(height: 12),
            
            // --- 2. The Bespoke Tagline ---
            Text(
              'Company Bespoke Suite',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PulseColors.primary,
                letterSpacing: 2.0,
              ),
            ).animate().fadeIn(delay: 800.ms),
            
            const SizedBox(height: 100), 
            
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
