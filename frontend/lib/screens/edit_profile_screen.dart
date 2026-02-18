import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;

  const EditProfileScreen({super.key, required this.user, required this.onUserUpdated});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _companyController;
  late TextEditingController _departmentController;
  late TextEditingController _experienceController;
  late TextEditingController _technologiesController;
  late TextEditingController _addressController;
  String? _selectedGender;
  XFile? _imageFile;
  bool _isLoading = false;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?['fullName'] ?? '');
    _emailController = TextEditingController(text: widget.user?['email'] ?? '');
    _companyController = TextEditingController(text: widget.user?['company'] ?? '');
    _departmentController = TextEditingController(text: widget.user?['department'] ?? '');
    _experienceController = TextEditingController(text: widget.user?['experience'] ?? '');
    _technologiesController = TextEditingController(text: widget.user?['technologies'] ?? '');
    _addressController = TextEditingController(text: widget.user?['address'] ?? '');
    _selectedGender = widget.user?['gender'];
    
    if (widget.user == null) {
      _loadUser();
    } else {
      _currentUser = widget.user;
    }
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getStoredUser();
    if (user != null && mounted) {
      setState(() {
        _currentUser = user;
        _nameController.text = user['fullName'] ?? '';
        _emailController.text = user['email'] ?? '';
        _companyController.text = user['company'] ?? '';
        _departmentController.text = user['department'] ?? '';
        _experienceController.text = user['experience'] ?? '';
        _technologiesController.text = user['technologies'] ?? '';
        _addressController.text = user['address'] ?? '';
        _selectedGender = user['gender'];
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _departmentController.dispose();
    _experienceController.dispose();
    _technologiesController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    
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
      final XFile? image = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image != null) {
        setState(() => _imageFile = image);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate() && _currentUser != null) {
      setState(() => _isLoading = true);
      try {
        final Map<String, dynamic> fields = {
          'fullName': _nameController.text,
          'email': _emailController.text,
          'company': _companyController.text,
          'department': _departmentController.text,
          'gender': _selectedGender,
          'experience': _experienceController.text,
          'technologies': _technologiesController.text,
          'address': _addressController.text,
        };
        final updatedUser = await ApiService.updateUser(_currentUser!['id'], fields, image: _imageFile);
        if (widget.onUserUpdated != null) {
          widget.onUserUpdated!(updatedUser);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3E5F5),
      child: _currentUser == null 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: _imageFile != null 
                            ? FileImage(File(_imageFile!.path)) 
                            : (_currentUser!['profilePicture'] != null 
                                ? NetworkImage(ApiService.getImageUrl(_currentUser!['profilePicture']))
                                : null) as ImageProvider?,
                        child: (_imageFile == null && _currentUser!['profilePicture'] == null) 
                            ? const Icon(Icons.camera_alt, size: 40) 
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Enter email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyController,
                      decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _departmentController,
                      decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) => setState(() => _selectedGender = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _experienceController,
                      decoration: const InputDecoration(labelText: 'Experience (e.g., 5 years)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _technologiesController,
                      decoration: const InputDecoration(labelText: 'Technologies/Skills', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading ? const CircularProgressIndicator() : const Text('SAVE CHANGES'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
