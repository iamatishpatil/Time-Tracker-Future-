import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_button.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController(text: '9999');
  final _passwordController = TextEditingController();

  String _completePhoneNumber = '';
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_completePhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter mobile number')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.sendOtp(mobileNumber: _completePhoneNumber);
      setState(() => _otpSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_otpController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter OTP and new password')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.resetPassword(_completePhoneNumber, _otpController.text, _passwordController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PulseColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded, size: 48, color: PulseColors.primary),
            ),
            const SizedBox(height: 24),
            Text('Forgot Password?', style: PulseTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              _otpSent
                  ? 'Enter the OTP sent to your mobile'
                  : 'Enter your mobile number to receive an OTP',
              textAlign: TextAlign.center,
              style: PulseTextStyles.body,
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PulseColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: PulseColors.border),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !_otpSent
                    ? Column(
                        key: const ValueKey('phone'),
                        children: [
                          IntlPhoneField(
                            controller: _mobileController,
                            decoration: const InputDecoration(labelText: 'Mobile Number'),
                            initialCountryCode: 'IN',
                            style: PulseTextStyles.bodyBold.copyWith(color: Colors.white),
                            dropdownTextStyle: PulseTextStyles.body,
                            dropdownIcon: const Icon(Icons.arrow_drop_down, color: PulseColors.textHint),
                            flagsButtonPadding: const EdgeInsets.only(left: 12),
                            onChanged: (phone) {
                              _completePhoneNumber = phone.completeNumber;
                            },
                          ),
                          const SizedBox(height: 24),
                          PulseButton(
                            text: 'Send OTP',
                            onPressed: _isLoading ? null : _sendOtp,
                            isLoading: _isLoading,
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('otp'),
                        children: [
                          TextFormField(
                            controller: _otpController,
                            decoration: const InputDecoration(
                              labelText: 'Enter OTP',
                              prefixIcon: Icon(Icons.security_rounded),
                            ),
                            keyboardType: TextInputType.number,
                            style: PulseTextStyles.bodyBold.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'New Password',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            obscureText: true,
                            style: PulseTextStyles.bodyBold.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 24),
                          PulseButton(
                            text: 'Reset Password',
                            onPressed: _isLoading ? null : _resetPassword,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => setState(() => _otpSent = false),
                            child: Text('Change Mobile Number',
                                style: PulseTextStyles.caption.copyWith(color: PulseColors.primaryLight)),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
