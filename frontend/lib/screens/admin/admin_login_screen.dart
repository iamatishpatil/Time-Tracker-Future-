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
import '../../core/widgets/pulse_scaffold.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> with SingleTickerProviderStateMixin {
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
        localizedReason: 'Scan your fingerprint to login as admin',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
    } catch (e) {
      debugPrint('Error auth: $e');
    }

    if (authenticated && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final mobile = prefs.getString('saved_admin_mobile');
      final password = prefs.getString('saved_admin_password');

      if (mobile != null && password != null) {
        setState(() {
          _completePhoneNumber = mobile;
          _passwordController.text = password;
        });
        _login();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No saved admin credentials. Login manually first.')));
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
          final user = response['user'];
          if (user['role'] == 'Admin') {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('saved_admin_mobile', _completePhoneNumber);
            await prefs.setString('saved_admin_password', _passwordController.text);

            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => const AdminContainer()));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Access Denied: You are not an Admin')),
            );
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
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                              },
                              child: Text('Forgot Password?', style: PulseTextStyles.body.copyWith(color: PulseColors.primary)),
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
                              child: IconButton(
                                icon: Icon(Icons.fingerprint, size: 48, color: PulseColors.primary),
                                onPressed: _authenticate,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () {
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
                              color: PulseColors.primary,
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
