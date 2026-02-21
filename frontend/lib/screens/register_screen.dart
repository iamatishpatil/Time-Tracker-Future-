import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_button.dart';
import '../services/api_service.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _experienceController = TextEditingController();
  final _technologiesController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyController = TextEditingController();

  String _completePhoneNumber = '';
  String? _selectedGender;
  String _selectedRole = 'User';
  XFile? _profileImage;
  bool _isLoading = false;
  bool _isMobileVerified = false;
  bool _isEmailVerified = false;

  double? _latitude;
  double? _longitude;

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
      final XFile? image = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image != null) {
        setState(() => _profileImage = image);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });

        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          _addressController.text = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
        }
      } catch (e) {
        debugPrint('Error getting location: $e');
      }
    }
  }

  Future<void> _sendVerificationOtp(String type, String value) async {
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter $type')));
      return;
    }

    if (type == 'Mobile' && value.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Mobile Number')));
      return;
    }
    if (type == 'Email' && !value.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Email')));
      return;
    }

    try {
      String? mobile = type == 'Mobile' ? value : null;
      String? email = type == 'Email' ? value : null;

      await ApiService.sendOtp(mobileNumber: mobile, email: email);
      if (mounted) {
        _showVerificationDialog(type, value);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showVerificationDialog(String type, String value) {
    TextEditingController otpController = TextEditingController(text: '9999');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Verify $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OTP sent to $value.\n(Check server terminal)',
                style: PulseTextStyles.caption),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              decoration: const InputDecoration(labelText: 'Enter OTP'),
              keyboardType: TextInputType.number,
              style: PulseTextStyles.bodyBold.copyWith(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                String? mobile = type == 'Mobile' ? value : null;
                String? email = type == 'Email' ? value : null;

                await ApiService.verifyOtp(mobileNumber: mobile, email: email, otp: otpController.text);

                if (mounted) {
                  setState(() {
                    if (type == 'Mobile') _isMobileVerified = true;
                    if (type == 'Email') _isEmailVerified = true;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type Verified!')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      if (!_isMobileVerified) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify Mobile Number')));
        return;
      }
      if (!_isEmailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify Email')));
        return;
      }

      if (_selectedGender == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Gender')));
        return;
      }
      if (_profileImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a Profile Picture')));
        return;
      }

      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      Map<String, String> fields = {
        'fullName': _fullNameController.text,
        'email': _emailController.text,
        'mobileNumber': _completePhoneNumber,
        'gender': _selectedGender!,
        'password': _passwordController.text,
        'company': _companyController.text,
        'role': _selectedRole,
        'experience': _experienceController.text,
        'technologies': _technologiesController.text,
        'address': _addressController.text,
        'latitude': _latitude?.toString() ?? '',
        'longitude': _longitude?.toString() ?? '',
      };

      try {
        await ApiService.register(fields, _profileImage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration Successful! Please login.')),
          );
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Picture
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: PulseColors.surfaceVariant,
                      backgroundImage: _profileImage != null ? FileImage(File(_profileImage!.path)) : null,
                      child: _profileImage == null
                          ? const Icon(Icons.camera_alt_rounded, size: 32, color: PulseColors.textHint)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: PulseColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Upload Photo', style: PulseTextStyles.caption),
              const SizedBox(height: 24),

              // Section: Personal Info
              _sectionHeader('Personal Information'),
              const SizedBox(height: 12),
              _buildField(_fullNameController, 'Full Name', Icons.person_outline_rounded),
              const SizedBox(height: 16),

              // Email with verify
              _buildField(
                _emailController,
                'Email',
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                readOnly: _isEmailVerified,
              ),
              _verifyRow('Email', _isEmailVerified, () => _sendVerificationOtp('Email', _emailController.text)),
              const SizedBox(height: 8),

              // Phone with verify
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
                validator: (value) {
                  if (value == null || value.number.isEmpty) return 'Enter mobile number';
                  if (value.number.length != 10) return 'Must be 10 digits';
                  return null;
                },
                enabled: !_isMobileVerified,
              ),
              _verifyRow('Mobile', _isMobileVerified, () => _sendVerificationOtp('Mobile', _completePhoneNumber)),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.people_outline_rounded),
                ),
                dropdownColor: PulseColors.surfaceVariant,
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.admin_panel_settings_rounded),
                ),
                dropdownColor: PulseColors.surfaceVariant,
                items: const [
                  DropdownMenuItem(value: 'User', child: Text('User / Employee')),
                  DropdownMenuItem(value: 'Admin', child: Text('Admin / Company Owner')),
                ],
                onChanged: (value) => setState(() => _selectedRole = value!),
              ),
              const SizedBox(height: 16),

              _buildField(_passwordController, 'Password', Icons.lock_outline_rounded, obscureText: true),

              const SizedBox(height: 24),
              _sectionHeader('Professional Details'),
              const SizedBox(height: 12),
              _buildField(_companyController, 'Company Name', Icons.business_rounded),
              const SizedBox(height: 16),
              _buildField(_experienceController, 'Work Experience', Icons.work_outline_rounded),
              const SizedBox(height: 16),
              _buildField(_technologiesController, 'Technologies', Icons.code_rounded),
              const SizedBox(height: 16),
              _buildField(
                _addressController,
                'Address',
                Icons.home_outlined,
                maxLines: 2,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location_rounded, color: PulseColors.accent),
                  onPressed: _getCurrentLocation,
                  tooltip: 'Get Current Location',
                ),
              ),

              const SizedBox(height: 32),
              PulseButton(
                text: 'Create Account',
                onPressed: _isLoading ? null : _register,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: PulseTextStyles.h3.copyWith(fontSize: 16)),
    );
  }

  Widget _verifyRow(String type, bool isVerified, VoidCallback onVerify) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isVerified)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 16, color: PulseColors.success),
                const SizedBox(width: 4),
                Text('Verified', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.success)),
              ],
            )
          else
            TextButton(
              onPressed: onVerify,
              child: Text('Verify $type',
                  style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primaryLight)),
            ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon,
      {bool obscureText = false, TextInputType? keyboardType, int maxLines = 1,
       bool readOnly = false, Widget? suffixIcon}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      style: PulseTextStyles.bodyBold.copyWith(color: Colors.white),
      onChanged: (value) {
        if (label == 'Email' && _isEmailVerified) {
          setState(() => _isEmailVerified = false);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) return '$label is required';
        if (label == 'Email') {
          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
          if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
        }
        if (label == 'Password' && value.length < 6) return 'Min 6 characters';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
