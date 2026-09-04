import 'package:flutter/material.dart';
import 'package:frontend/core/theme/pulse_colors.dart';
import 'package:frontend/core/theme/pulse_text_styles.dart';
import 'package:frontend/core/widgets/pulse_button.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/services/firebase_sms_service.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:frontend/core/widgets/pulse_scaffold.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyController = TextEditingController();
  final _departmentController = TextEditingController();

  String _completePhoneNumber = '';
  XFile? _profileImage;
  bool _isLoading = false;
  bool _isMobileVerified = false;
  bool _isEmailVerified = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) setState(() => _profileImage = image);
    }
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      if (!_isMobileVerified || !_isEmailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify Mobile and Email')));
        return;
      }
      if (_profileImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a Profile Picture')));
        return;
      }

      setState(() => _isLoading = true);

      Map<String, String> fields = {
        'fullName': _fullNameController.text,
        'email': _emailController.text,
        'mobileNumber': _completePhoneNumber,
        'password': _passwordController.text,
        'company': _companyController.text,
        'department': _departmentController.text.isEmpty ? 'Corporate' : _departmentController.text,
        'role': 'Admin',
        'isActive': '1',
      };

      try {
        await ApiService.register(fields, _profileImage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin Registered Successfully!')),
          );
          Navigator.pushReplacementNamed(context, '/admin-login');
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verify(String type) async {
    String value = '';
    if (type == 'Mobile') {
      value = _completePhoneNumber.isNotEmpty 
          ? _completePhoneNumber 
          : (_mobileController.text.isNotEmpty ? '+91${_mobileController.text}' : '');
    } else {
      value = _emailController.text.trim();
    }

    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter $type first')));
      return;
    }
    
    if (type == 'Mobile') {
      await FirebaseSmsService.sendSmsOtp(
        phoneNumber: value,
        context: context,
        onCodeSent: (verificationId) {
          _showFirebaseSmsDialog(value, verificationId);
        },
        onAutoVerified: () {
          if (mounted) {
            setState(() => _isMobileVerified = true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile verified via SMS!')));
          }
        },
        onError: (error) {
          debugPrint('[Firebase Phone Auth] $error. Falling back to Backend OTP.');
          _triggerBackendOtp(type, value);
        },
      );
    } else {
      _triggerBackendOtp(type, value);
    }
  }

  Future<void> _triggerBackendOtp(String type, String value) async {
    try {
      final res = await ApiService.sendOtp(
        mobileNumber: type == 'Mobile' ? value : null,
        email: type == 'Email' ? value : null,
      );
      final String? devOtp = res['otp']?.toString();

      if (mounted) {
        _showOtpDialog(type, value, devOtp: devOtp);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send OTP: ${e.toString()}')));
    }
  }

  void _showFirebaseSmsDialog(String mobileNumber, String verificationId) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Mobile SMS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the 6-digit SMS text code sent by Firebase to $mobileNumber.', style: PulseTextStyles.caption),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '6-Digit SMS Code'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              final success = await FirebaseSmsService.verifySmsCode(
                verificationId: verificationId,
                smsCode: code,
              );
              if (mounted) {
                Navigator.pop(ctx);
                if (success) {
                  setState(() => _isMobileVerified = true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile verified via SMS!')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid SMS Code. Try again.')));
                }
              }
            },
            child: const Text('Verify SMS'),
          ),
        ],
      ),
    );
  }

  void _showOtpDialog(String type, String value, {String? devOtp}) {
    final controller = TextEditingController(text: devOtp ?? '');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Verify $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(devOtp != null ? 'OTP sent to $value\n(Dev Code: $devOtp)' : 'Enter the verification code sent to $value', style: PulseTextStyles.caption),
            const SizedBox(height: 16),
            TextField(controller: controller, decoration: const InputDecoration(labelText: 'OTP Code')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.verifyOtp(
                  mobileNumber: type == 'Mobile' ? value : null,
                  email: type == 'Email' ? value : null,
                  otp: controller.text,
                );
                setState(() {
                  if (type == 'Mobile') _isMobileVerified = true;
                  if (type == 'Email') _isEmailVerified = true;
                });
                Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: 'Setup Admin Hub',
      useBrandedBackground: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: PulseColors.primary.withOpacity(0.1),
                  backgroundImage: _profileImage != null ? FileImage(File(_profileImage!.path)) : null,
                  child: _profileImage == null ? Icon(Icons.add_a_photo_outlined, color: PulseColors.primary) : null,
                ),
              ),
              const SizedBox(height: 8),
              Text('Admin Profile Photo', style: PulseTextStyles.captionBold),
              const SizedBox(height: 32),
              
              _sectionTitle('Company Details'),
              _buildField(_companyController, 'Company Name', Icons.business_center_rounded),
              const SizedBox(height: 16),
              _buildField(_departmentController, 'Department / Branch', Icons.layers_outlined),
              
              const SizedBox(height: 32),
              _sectionTitle('Admin Credentials'),
              _buildField(_fullNameController, 'Full Name', Icons.badge_outlined),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emailController,
                style: PulseTextStyles.bodyBold,
                decoration: InputDecoration(
                  labelText: 'Work Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: _isEmailVerified ? const Icon(Icons.verified, color: Colors.green) : TextButton(
                    onPressed: _isLoading ? null : () => _verify('Email'), 
                    child: Text('Verify', style: TextStyle(color: _isLoading ? PulseColors.textHint : PulseColors.primary)),
                  ),
                ),
                readOnly: _isEmailVerified,
                validator: (val) => (val == null || val.isEmpty) ? 'Email required' : null,
              ),
              const SizedBox(height: 16),
              
              IntlPhoneField(
                controller: _mobileController,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  suffixIcon: _isMobileVerified ? const Icon(Icons.verified, color: Colors.green) : null,
                ),
                initialCountryCode: 'IN',
                enabled: !_isMobileVerified,
                onChanged: (phone) => _completePhoneNumber = phone.completeNumber,
              ),
              if (!_isMobileVerified) Align(
                alignment: Alignment.centerRight, 
                child: TextButton(
                  onPressed: _isLoading ? null : () => _verify('Mobile'), 
                  child: Text('Verify Mobile', style: TextStyle(color: _isLoading ? PulseColors.textHint : PulseColors.primary)),
                ),
              ),
              
              const SizedBox(height: 16),
              _buildField(_passwordController, 'Security Password', Icons.lock_reset_rounded, obscureText: true),
              
              const SizedBox(height: 48),
              PulseButton(
                text: 'Launch Admin Hub',
                onPressed: _isLoading ? null : _register,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have a hub? ", style: PulseTextStyles.body),
                  GestureDetector(
                    onTap: _isLoading ? null : () => Navigator.pushReplacementNamed(context, '/admin-login'),
                    child: Text('Login Admin',
                        style: PulseTextStyles.bodyBold.copyWith(color: _isLoading ? PulseColors.textHint : PulseColors.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 4, height: 18, color: PulseColors.primary),
          const SizedBox(width: 8),
          Text(title, style: PulseTextStyles.h3),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: PulseTextStyles.bodyBold,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (val) => (val == null || val.isEmpty) ? '$label required' : null,
    );
  }
}
