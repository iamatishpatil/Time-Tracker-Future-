import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_button.dart';
import '../services/api_service.dart';
import 'admin/admin_dashboard_screen.dart';
import 'forgot_password_screen.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  String _completePhoneNumber = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;

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
    bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (e) {
      canCheckBiometrics = false;
    }
    if (mounted) setState(() => _canCheckBiometrics = canCheckBiometrics);
  }

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
        _login();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No saved credentials. Login manually first.')));
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
        final response = await ApiService.login(
          _completePhoneNumber,
          _passwordController.text,
        );

        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_mobile', _completePhoneNumber);
          await prefs.setString('saved_password', _passwordController.text);

          final user = response['user'];
          if (user['role'] == 'Admin') {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => AdminDashboardScreen()));
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A14), Color(0xFF0F0F1A), Color(0xFF151528)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: PulseColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: PulseColors.primary.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.access_time_filled_rounded, size: 44, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text('Time Tracker', style: PulseTextStyles.h1),
                    const SizedBox(height: 8),
                    Text('Track your work, effortlessly', style: PulseTextStyles.body),
                    const SizedBox(height: 40),

                    // Login Card
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
                            Text('Welcome Back', style: PulseTextStyles.h2),
                            const SizedBox(height: 4),
                            Text('Sign in to continue', style: PulseTextStyles.caption),
                            const SizedBox(height: 28),

                            IntlPhoneField(
                              controller: _mobileController,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                              ),
                              initialCountryCode: 'IN',
                              dropdownTextStyle: PulseTextStyles.body,
                              style: PulseTextStyles.bodyBold.copyWith(color: Colors.white),
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
                              style: PulseTextStyles.bodyBold.copyWith(color: Colors.white),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Enter password';
                                return null;
                              },
                            ),

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

                            PulseButton(
                              text: 'Sign In',
                              onPressed: _isLoading ? null : _login,
                              isLoading: _isLoading,
                            ),

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
      ),
    );
  }
}
