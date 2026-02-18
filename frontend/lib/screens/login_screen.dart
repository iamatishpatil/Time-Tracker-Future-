import 'package:flutter/material.dart';
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

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _completePhoneNumber = '';
  bool _isLoading = false;
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No saved credentials. Login manually first.')));
       }
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
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
           // Save credentials
           final prefs = await SharedPreferences.getInstance();
           await prefs.setString('saved_mobile', _completePhoneNumber);
           await prefs.setString('saved_password', _passwordController.text);

          final user = response['user'];
          if (user['role'] == 'Admin') {
             Navigator.pushReplacement(
               context, 
               MaterialPageRoute(builder: (context) => AdminDashboardScreen())
             );
          } else {
             Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
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
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time_filled_rounded, size: 80, color: Color(0xFF6200EA)),
              const SizedBox(height: 20),
              Text(
                'Time Tracker',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF6200EA),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('Sign in to continue', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 30),
                        
                        IntlPhoneField(
                          controller: _mobileController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          initialCountryCode: 'IN',
                          onChanged: (phone) {
                            _completePhoneNumber = phone.completeNumber;
                          },
                          validator: (value) {
                            if (value == null || value.number.isEmpty) return 'Enter mobile number';
                            if (value.number.length != 10) return 'Must be 10 digits';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (val) {
                             if (val == null || val.isEmpty) return 'Enter password';
                             return null;
                          },
                        ),
                        
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                            },
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6200EA),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : const Text('LOGIN', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        
                        if (_canCheckBiometrics) ...[
                          const SizedBox(height: 20),
                          IconButton(
                            icon: const Icon(Icons.fingerprint, size: 50, color: Color(0xFF6200EA)),
                            onPressed: _authenticate,
                          ),
                          const Text('Touch to Login', style: TextStyle(color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Text("Don't have an account? "),
                   GestureDetector(
                     onTap: () => Navigator.pushNamed(context, '/register'),
                     child: const Text('Sign Up', style: TextStyle(color: Color(0xFF6200EA), fontWeight: FontWeight.bold)),
                   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
