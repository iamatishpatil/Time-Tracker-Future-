import 'package:flutter/material.dart';
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
  
  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _experienceController = TextEditingController();
  final _technologiesController = TextEditingController();
  final _addressController = TextEditingController();

  String _completePhoneNumber = '';
  String? _selectedGender;
  XFile? _profileImage;
  bool _isLoading = false;
  bool _isMobileVerified = false;
  bool _isEmailVerified = false;
  
  // Locations
  double? _latitude;
  double? _longitude;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
      ),
    );

    if (source != null) {
      final XFile? image = await _picker.pickImage(source: source);
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

  // OTP Logic (Mock)
  Future<void> _sendVerificationOtp(String type, String value) async {
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter $type')));
      return;
    }
    
    // Simple validation before sending
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
    TextEditingController otpController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Verify $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OTP sent to $value.\\n(Check server terminal)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              decoration: const InputDecoration(labelText: 'Enter OTP', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select Gender')),
        );
        return;
      }
      if (_profileImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a Profile Picture')),
        );
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
        'role': 'User',
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
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _profileImage != null ? FileImage(File(_profileImage!.path)) : null,
                  child: _profileImage == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey) : null,
                ),
              ),
              const SizedBox(height: 10),
              const Text('Tap to upload profile picture'),
              const SizedBox(height: 24),
              
              _buildTextField(_fullNameController, 'Full Name', Icons.person),
              const SizedBox(height: 16),
              
              // Email
              _buildTextField(
                _emailController, 
                'Email', 
                Icons.email, 
                keyboardType: TextInputType.emailAddress, 
                readOnly: _isEmailVerified
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isEmailVerified)
                    const Text("Verified ✓", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                  else
                    TextButton(
                      onPressed: () => _sendVerificationOtp('Email', _emailController.text),
                      child: const Text('Verify Email'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              
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
                enabled: !_isMobileVerified, 
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   if (_isMobileVerified)
                      const Text("Verified ✓", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                    else
                      TextButton(
                        onPressed: () => _sendVerificationOtp('Mobile', _completePhoneNumber),
                        child: const Text('Verify Mobile'),
                      ),
                ],
              ),

              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(_passwordController, 'Password', Icons.lock, obscureText: true),
              const SizedBox(height: 16),
              
              _buildTextField(_experienceController, 'Work Experience', Icons.work),
              const SizedBox(height: 16),
              
              _buildTextField(_technologiesController, 'Technologies', Icons.code),
              const SizedBox(height: 16),
              
              _buildTextField(
                _addressController, 
                'Address', 
                Icons.home, 
                maxLines: 2,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location), 
                  onPressed: _getCurrentLocation,
                  tooltip: 'Get Current Location',
                ),
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                   style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6200EA),
                      foregroundColor: Colors.white,
                    ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('REGISTER', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false, TextInputType? keyboardType, int maxLines = 1, bool readOnly = false, Widget? suffixIcon}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: (value) {
        if (label == 'Email' && _isEmailVerified) {
          setState(() => _isEmailVerified = false);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
