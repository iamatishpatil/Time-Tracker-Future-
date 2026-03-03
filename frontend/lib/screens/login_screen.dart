import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_button.dart';
import '../services/api_service.dart';
import 'admin/admin_container.dart';
import 'forgot_password_screen.dart';
import '../core/widgets/branded_logo.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/branding_provider.dart';
import '../core/widgets/pulse_scaffold.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

// --- 1. Login Screen (StatefulWidget) ---
// We use a ConsumerStatefulWidget because this screen needs to "remember" things
// like what the user typed or if a loading spinner is showing.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

// This is where the actual "Brain" and "Body" of the LoginScreen live.
class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  // GlobalKey is like a "Handle" to control and validate the Form.
  final _formKey = GlobalKey<FormState>();

  // Controllers "listen" to what you type in the text boxes.
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  String _completePhoneNumber = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isAdminSelected = false;

  // Biometric authentication (Fingerprint/Face ID)
  final LocalAuthentication auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  bool _canCheckBiometrics = false;
  bool _isFaceId = false;
  bool _isBiometricEnrolled = false;

  // Animation variables to make the screen look smooth
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // initState runs ONCE when the screen first appears.
  @override
  void initState() {
    super.initState();
    _checkBiometrics(); // Check if the phone supports fingerprints

    // Set up the "fade-in" and "slide-up" animations
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward(); // Start the animation
  }

  // Check if fingerprint/face ID is available on this device
  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics = false;
    bool isFaceId = false;
    bool isBiometricEnrolled = false;
    
    try {
      canCheckBiometrics = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canCheckBiometrics) {
        final availableBiometrics = await auth.getAvailableBiometrics();
        if (availableBiometrics.contains(BiometricType.face) || 
            availableBiometrics.contains(BiometricType.strong)) {
          isFaceId = true;
        }
        isBiometricEnrolled = await auth.isDeviceSupported();
      }
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
    }
    
    if (mounted) {
      setState(() {
        _canCheckBiometrics = canCheckBiometrics;
        _isFaceId = isFaceId;
        _isBiometricEnrolled = isBiometricEnrolled;
      });
    }
  }

  // The actual Biometric Login process
  Future<void> _authenticate() async {
    try {
      // 1. Trigger the device's biometric prompt
      final String biometricType = _isFaceId ? 'Face' : 'Fingerprint';
      final bool authenticated = await auth.authenticate(
        localizedReason: 'Authenticate with $biometricType to login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated && mounted) {
        setState(() => _isLoading = true);
        
        // 2. Retrieve the secure biometric token from the phone's "Vault"
        final tokenKey = _isAdminSelected ? 'admin_biometric_token' : 'user_biometric_token';
        final biometricToken = await _storage.read(key: tokenKey);

        if (biometricToken != null) {
          // 3. Log in directly using the token
          final response = await ApiService.loginWithBiometric(biometricToken);
          if (mounted) _handleLoginSuccess(response);
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric not linked. Please login with password first.')),
          );
        }
      }
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
      setState(() => _isLoading = false);
    }
  }

  void _handleLoginSuccess(Map<String, dynamic> response) async {
    final user = response['user'];

    // Pre-fetch the branding in the background without blocking navigation
    // This removes the "stuck" feeling after a successful login
    ref.read(brandingProvider.notifier).fetchBranding(company: user['company']).catchError((e) {
      debugPrint("Background branding fetch failed: $e");
    });

    if (_isAdminSelected) {
      if (user['role'] == 'Admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminContainer()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access Denied: You are not an Admin.')),
        );
      }
    } else {
      if (user['role'] == 'Admin') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access Denied: Please use Admin portal.')),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  // dispose runs when you leave the screen to "clean up" memory.
  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // --- The Login Logic ---
  void _login() async {
    // 1. Check if the inputs are valid (e.g., 10 digits for phone)
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true); // Show the loading spinner
      try {
        // 2. Generate or retrieve biometric token for security
        final tokenKey = _isAdminSelected ? 'admin_biometric_token' : 'user_biometric_token';
        String? biometricToken = await _storage.read(key: tokenKey);
        
        if (biometricToken == null) {
           biometricToken = const Uuid().v4();
           await _storage.write(key: tokenKey, value: biometricToken);
        }

        // 3. Send the data to the server
        final response = await ApiService.login(
          _completePhoneNumber,
          _passwordController.text,
          biometricToken: biometricToken,
        );

        if (mounted) {
          _handleLoginSuccess(response);
        }
      } catch (e) {
        // Show an error message if login fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false); // Hide the loading spinner
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      useBrandedBackground: true,
      body: Center(
        child: SafeArea(
          child: SingleChildScrollView( // Allows scrolling if the screen is small
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: FadeTransition( // Applies the fade-in animation
              opacity: _fadeAnimation,
              child: SlideTransition( // Applies the slide-up animation
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The Branded Logo at the top
                    BrandedLogo(size: 100, showText: false),
                    const SizedBox(height: 24),
                    Text('Trackzo', style: PulseTextStyles.h1),
                    const SizedBox(height: 8),
                    Text(_isAdminSelected ? 'Manage your organization securely' : 'Track your work, effortlessly', style: PulseTextStyles.body),
                    const SizedBox(height: 40),

                    // --- The Main Login Card ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: PulseColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: PulseColors.border),
                      ),
                      child: Form(
                        key: _formKey, // Connects the form to our validation key
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isAdminSelected ? 'Admin Portal' : 'Welcome Back', style: PulseTextStyles.h2),
                            const SizedBox(height: 4),
                            Text(_isAdminSelected ? 'Sign in to access admin privileges' : 'Sign in to continue', style: PulseTextStyles.caption),
                            const SizedBox(height: 32),

                            // Role Toggle
                            Container(
                              height: 45,
                              decoration: BoxDecoration(
                                color: PulseColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: PulseColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _isLoading ? null : () => setState(() => _isAdminSelected = false),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: !_isAdminSelected ? PulseColors.primary : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Employee',
                                          style: PulseTextStyles.captionBold.copyWith(
                                            color: !_isAdminSelected ? Colors.white : PulseColors.textHint,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _isLoading ? null : () => setState(() => _isAdminSelected = true),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _isAdminSelected ? PulseColors.primary : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Admin',
                                          style: PulseTextStyles.captionBold.copyWith(
                                            color: _isAdminSelected ? Colors.white : PulseColors.textHint,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Phone Input Field
                            IntlPhoneField(
                              controller: _mobileController,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                              ),
                              initialCountryCode: 'IN',
                              dropdownTextStyle: PulseTextStyles.body,
                              style: PulseTextStyles.bodyBold,
                              dropdownIcon: const Icon(Icons.arrow_drop_down, color: PulseColors.textHint),
                              flagsButtonPadding: const EdgeInsets.only(left: 12),
                              onChanged: (phone) {
                                _completePhoneNumber = phone.completeNumber;
                              },
                              validator: (value) {
                                if (value == null || value.number.isEmpty) return 'Enter mobile number';
                                if (value.number.length != 10) return 'Must be 10 digits';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Input Field
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              style: PulseTextStyles.bodyBold,
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Enter password';
                                return null;
                              },
                            ),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : () {
                                  Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                                },
                                child: Text('Forgot Password?',
                                    style: PulseTextStyles.caption.copyWith(
                                      color: _isLoading ? PulseColors.textHint : PulseColors.primaryLight,
                                    )),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // The Sign In Button
                            PulseButton(
                              text: _isAdminSelected ? 'Admin Login' : 'Sign In',
                              onPressed: _isLoading ? null : _login,
                              isLoading: _isLoading,
                            ),

                            // Fingerprint Login Option (if available)
                            if (_canCheckBiometrics) ...[
                              const SizedBox(height: 20),
                              Center(
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onTap: _isLoading ? null : _authenticate,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: _isLoading ? PulseColors.surfaceVariant : PulseColors.surfaceVariant,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: PulseColors.border),
                                        ),
                                        child: _isLoading 
                                          ? SizedBox(
                                              width: 36, 
                                              height: 36, 
                                              child: CircularProgressIndicator(strokeWidth: 3, color: PulseColors.primary)
                                            )
                                          : Icon(
                                              _isFaceId ? Icons.face_rounded : Icons.fingerprint,
                                              size: 36, 
                                              color: PulseColors.primary
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                        'Login with ${_isFaceId ? "Face ID" : "Biometrics"}', 
                                        style: PulseTextStyles.caption
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // --- Bottom Sign Up Link ---
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_isAdminSelected ? "Register your company? " : "Don't have an account? ", style: PulseTextStyles.body),
                        GestureDetector(
                          onTap: _isLoading ? null : () => Navigator.pushNamed(context, _isAdminSelected ? '/admin-register' : '/register'),
                          child: Text('Sign Up',
                              style: PulseTextStyles.bodyBold.copyWith(
                                color: _isLoading ? PulseColors.textHint : PulseColors.primary,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
