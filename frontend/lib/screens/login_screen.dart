import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_button.dart';
import '../services/api_service.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/admin_container.dart';
import 'forgot_password_screen.dart';
import '../core/widgets/branded_background.dart';
import '../core/widgets/branded_logo.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/widgets/pulse_scaffold.dart';

// --- 1. Login Screen (StatefulWidget) ---
// We use a StatefulWidget because this screen needs to "remember" things 
// like what the user typed or if a loading spinner is showing.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// This is where the actual "Brain" and "Body" of the LoginScreen live.
class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // GlobalKey is like a "Handle" to control and validate the Form.
  final _formKey = GlobalKey<FormState>();
  
  // Controllers "listen" to what you type in the text boxes.
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  String _completePhoneNumber = '';
  bool _isLoading = false; // Tracks if we are currently talking to the server
  bool _obscurePassword = true; // Tracks if the password should be hidden (dots)
  
  // Biometric authentication (Fingerprint/Face ID)
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;

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
    bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (e) {
      canCheckBiometrics = false;
    }
    if (mounted) setState(() => _canCheckBiometrics = canCheckBiometrics);
  }

  // The actual Biometric Login process
  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Scan your fingerprint to login',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
    } catch (e) {
      debugPrint('Error auth: $e');
    }

    if (authenticated && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final mobile = prefs.getString('saved_mobile');
      final password = prefs.getString('saved_password');

      if (mobile != null && password != null) {
        setState(() {
          _completePhoneNumber = mobile;
          _passwordController.text = password;
        });
        _login(); // Automatically login if fingerprint matches saved data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No saved credentials. Login manually first.')));
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
        // 2. Send the data to the server
        final response = await ApiService.login(
          _completePhoneNumber,
          _passwordController.text,
        );

        if (mounted) {
          // 3. Save the credentials locally so biometrics work next time
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_mobile', _completePhoneNumber);
          await prefs.setString('saved_password', _passwordController.text);

          final user = response['user'];
          // 4. Decide where to go next based on user role (Admin or User)
          if (user['role'] == 'Admin') {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => const AdminContainer()));
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
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
          child: SingleChildScrollView( // Allows scrolling if the screen is small
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    Text('Time Tracker', style: PulseTextStyles.h1),
                    const SizedBox(height: 8),
                    Text('Track your work, effortlessly', style: PulseTextStyles.body),
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
                            Text('Welcome Back', style: PulseTextStyles.h2),
                            const SizedBox(height: 4),
                            Text('Sign in to continue', style: PulseTextStyles.caption),
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
                                onPressed: () {
                                  Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                                },
                                child: Text('Forgot Password?',
                                    style: PulseTextStyles.caption.copyWith(color: PulseColors.primaryLight)),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // The Sign In Button
                            PulseButton(
                              text: 'Sign In',
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
                                      onTap: _authenticate,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: PulseColors.surfaceVariant,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: PulseColors.border),
                                        ),
                                        child: Icon(Icons.fingerprint,
                                            size: 36, color: PulseColors.primary),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Biometric Login', style: PulseTextStyles.caption),
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
                        Text("Don't have an account? ", style: PulseTextStyles.body),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/register'),
                          child: Text('Sign Up',
                              style: PulseTextStyles.bodyBold.copyWith(color: PulseColors.primary)),
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
    );
  }
}
