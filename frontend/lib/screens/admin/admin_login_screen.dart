import 'package:flutter/material.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_button.dart';
import '../../services/api_service.dart';
import 'admin_container.dart';
import '../forgot_password_screen.dart';
import '../../core/widgets/branded_logo.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/branding_provider.dart';
import '../../core/widgets/pulse_scaffold.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  String _completePhoneNumber = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _canCheckBiometrics = false;
  bool _hasFaceBiometric = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    
    _animController.forward();
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics = false;
    bool hasFace = false;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canCheckBiometrics) {
         List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();
         if (availableBiometrics.contains(BiometricType.face)) {
            hasFace = true;
         }
      }
    } catch (e) {
      canCheckBiometrics = false;
    }
    if (mounted) {
       setState(() {
          _canCheckBiometrics = canCheckBiometrics;
          _hasFaceBiometric = hasFace;
       });
    }
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Scan your ${_hasFaceBiometric ? "Face" : "Fingerprint"} to login as admin',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
    } catch (e) {
      debugPrint('Error auth: $e');
      if (mounted) {
         String errorMsg = e.toString();
         if (errorMsg.contains('NotEnrolled') || errorMsg.contains('NotAvailable')) {
            errorMsg = 'No biometrics set up on this device. Please add a screen lock and fingerprint/face in Android settings.';
         } else {
            errorMsg = 'Biometric error: $errorMsg';
         }
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
      return;
    }

    if (authenticated && mounted) {
      setState(() => _isLoading = true);
      try {
        final String? storedToken = await _secureStorage.read(key: 'admin_biometric_token');
        if (storedToken != null) {
          final response = await ApiService.loginWithBiometric(storedToken);
          _handleSuccessfulLogin(response['user']);
        } else {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Biometric not linked. Please login manually first to link your device.'))
             );
          }
        }
      } catch (e) {
         if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text(e.toString()))
             );
          }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSuccessfulLogin(Map<String, dynamic> user) async {
    if (mounted) {
       // Pre-fetch the branding in the background without blocking navigation
       ref.read(brandingProvider.notifier).fetchBranding(company: user['company']).catchError((e) {
         debugPrint("Background branding fetch failed: $e");
       });

       if (user['role'] == 'Admin') {
           Navigator.pushReplacement(
               context, MaterialPageRoute(builder: (context) => const AdminContainer()));
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Access Denied: You are not an Admin. Please use the Employee portal.')),
           );
        }
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        String? bToken = await _secureStorage.read(key: 'admin_biometric_token');
        if (bToken == null) {
           bToken = const Uuid().v4();
           await _secureStorage.write(key: 'admin_biometric_token', value: bToken);
        }

        final response = await ApiService.login(
          _completePhoneNumber,
          _passwordController.text,
          biometricToken: bToken,
        );

        _handleSuccessfulLogin(response['user']);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      useBrandedBackground: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BrandedLogo(size: 100, showText: false),
                  const SizedBox(height: 24),
                  Text('Admin Portal', style: PulseTextStyles.h1),
                  const SizedBox(height: 8),
                  Text('Manage your organization securely', style: PulseTextStyles.body),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: PulseColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: PulseColors.border),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Login', style: PulseTextStyles.h2),
                          const SizedBox(height: 4),
                          Text('Sign in to access admin privileges', style: PulseTextStyles.caption),
                          const SizedBox(height: 28),

                          IntlPhoneField(
                            controller: _mobileController,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                            ),
                            initialCountryCode: 'IN',
                            dropdownTextStyle: PulseTextStyles.body,
                            style: PulseTextStyles.body,
                            onChanged: (phone) {
                              _completePhoneNumber = phone.completeNumber;
                            },
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: PulseColors.textHint,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            style: PulseTextStyles.body,
                            validator: (val) => val == null || val.isEmpty ? 'Please enter a password' : null,
                          ),
                          
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                              },
                              child: Text('Forgot Password?', style: PulseTextStyles.body.copyWith(
                                color: _isLoading ? PulseColors.textHint : PulseColors.primary,
                              )),
                            ),
                          ),
                          
                          const SizedBox(height: 8),

                          PulseButton(
                            text: 'Admin Login',
                            onPressed: _login,
                            isLoading: _isLoading,
                          ),

                           if (_canCheckBiometrics) ...[
                             const SizedBox(height: 16),
                             Center(
                               child: Column(
                                 children: [
                                   GestureDetector(
                                     onTap: _isLoading ? null : _authenticate,
                                     child: Container(
                                       padding: const EdgeInsets.all(12),
                                       decoration: BoxDecoration(
                                         color: PulseColors.surfaceVariant,
                                         shape: BoxShape.circle,
                                         border: Border.all(color: PulseColors.border),
                                       ),
                                       child: _isLoading 
                                         ? SizedBox(
                                             width: 36, 
                                             height: 36, 
                                             child: CircularProgressIndicator(strokeWidth: 3, color: PulseColors.primary)
                                           )
                                         : Icon(_hasFaceBiometric ? Icons.face : Icons.fingerprint, size: 36, color: PulseColors.primary),
                                     ),
                                   ),
                                   const SizedBox(height: 8),
                                   Text('Biometric Login', style: PulseTextStyles.caption),
                                 ],
                               )
                             ),
                           ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.pushNamed(context, '/admin-register');
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Register your company? ',
                        style: PulseTextStyles.body,
                        children: [
                          TextSpan(
                            text: 'Sign Up',
                            style: PulseTextStyles.body.copyWith(
                              color: _isLoading ? PulseColors.textHint : PulseColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
