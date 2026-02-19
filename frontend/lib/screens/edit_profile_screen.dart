import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_button.dart';
import '../services/api_service.dart';

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
    _nameController = TextEditingController(text: widget.user['fullName'] ?? '');
    _emailController = TextEditingController(text: widget.user['email'] ?? '');
    _companyController = TextEditingController(text: widget.user['company'] ?? '');
    _departmentController = TextEditingController(text: widget.user['department'] ?? '');
    _experienceController = TextEditingController(text: widget.user['experience'] ?? '');
    _technologiesController = TextEditingController(text: widget.user['technologies'] ?? '');
    _addressController = TextEditingController(text: widget.user['address'] ?? '');
    _selectedGender = widget.user['gender'];
    _currentUser = widget.user;
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
      backgroundColor: PulseColors.surfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: PulseColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: PulseColors.primary),
              title: Text('Gallery', style: PulseTextStyles.body.copyWith(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: PulseColors.primary),
              title: Text('Camera', style: PulseTextStyles.body.copyWith(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await picker.pickImage(source: source, preferredCameraDevice: CameraDevice.front);
      if (image != null) setState(() => _imageFile = image);
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
        widget.onUserUpdated(updatedUser);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Profile updated!')));
          if (Navigator.of(context).canPop()) Navigator.pop(context);
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
    return RefreshIndicator(
      onRefresh: _loadUser,
      child: _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: PulseColors.primary, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: PulseColors.primary.withOpacity(0.3),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: PulseColors.surfaceVariant,
                              backgroundImage: _imageFile != null
                                  ? FileImage(File(_imageFile!.path))
                                  : (_currentUser!['profilePicture'] != null
                                      ? NetworkImage(ApiService.getImageUrl(_currentUser!['profilePicture']))
                                      : null) as ImageProvider?,
                              child: (_imageFile == null && _currentUser!['profilePicture'] == null)
                                  ? const Icon(Icons.camera_alt, size: 30, color: PulseColors.textHint)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: PulseColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    _field(_nameController, 'Full Name *', Icons.person_outline,
                        validator: (v) => v!.isEmpty ? 'Enter name' : null),
                    _field(_emailController, 'Email *', Icons.email_outlined,
                        validator: (v) => v!.isEmpty ? 'Enter email' : null),
                    _field(_companyController, 'Company', Icons.business_outlined),
                    _field(_departmentController, 'Department', Icons.groups_outlined),

                    // Gender Dropdown
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        dropdownColor: PulseColors.surfaceVariant,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) => setState(() => _selectedGender = value),
                      ),
                    ),

                    _field(_experienceController, 'Experience', Icons.work_outline),
                    _field(_technologiesController, 'Technologies / Skills', Icons.code, maxLines: 2),
                    _field(_addressController, 'Address', Icons.location_on_outlined, maxLines: 2),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        initialValue: _currentUser?['weekOffs'] ?? 'Sunday',
                        readOnly: true,
                        enabled: false,
                        style: PulseTextStyles.body.copyWith(color: PulseColors.textHint),
                        decoration: const InputDecoration(
                          labelText: 'Week Offs (read-only)',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    PulseButton(
                      text: 'Save Changes',
                      isLoading: _isLoading,
                      onPressed: _saveProfile,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {String? Function(String?)? validator, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: PulseTextStyles.body.copyWith(color: Colors.white),
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: validator,
      ),
    );
  }
}
