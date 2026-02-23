// --- 11. The Employee Onboarding Form ---
// This is the "Data Entry" screen for the Admin. It collects everything 
// needed for a new staff member: from their phone number to their salary.

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../services/api_service.dart';

class EmployeeFormScreen extends StatefulWidget {
  final Map<String, dynamic>? employee;

  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _passwordController;
  late TextEditingController _salaryController;
  late TextEditingController _departmentController;

  String _role = 'User';
  int? _selectedShiftId;
  bool _isActive = true;
  List<dynamic> _shifts = [];
  bool _isLoading = false;
  XFile? _imageFile;
  String _fullMobileNumber = '';
  List<String> _selectedWeekOffs = [];

  bool get isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameController = TextEditingController(text: e?['fullName'] ?? '');
    _emailController = TextEditingController(text: e?['email'] ?? '');

    String mobileText = e?['mobileNumber'] ?? '';
    if (mobileText.startsWith('+91')) {
      mobileText = mobileText.substring(3);
    } else if (mobileText.startsWith('+')) {
      mobileText = mobileText.replaceFirst(RegExp(r'^\+\d{1,3}'), '');
    }
    _mobileController = TextEditingController(text: mobileText);
    _fullMobileNumber = e?['mobileNumber'] ?? '';

    _passwordController = TextEditingController();
    _salaryController = TextEditingController(text: (e?['salary'] ?? 0).toString());
    _departmentController = TextEditingController(text: e?['department'] ?? 'General');
    _role = e?['role'] ?? 'User';
    _selectedShiftId = e?['shiftId'];
    _isActive = e == null ? true : (e['isActive'] == 1 || e['isActive'] == true);

    if (e?['weekOffs'] != null) {
      _selectedWeekOffs = (e!['weekOffs'] as String).split(',').where((s) => s.isNotEmpty).toList();
    } else if (e == null) {
      _selectedWeekOffs = ['Sunday'];
    }

    _loadShifts();
  }

  Future<void> _loadShifts() async {
    try {
      final shifts = await ApiService.getShifts();
      if (mounted) setState(() => _shifts = shifts);
    } catch (e) {
      debugPrint('Error loading shifts: $e');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  // The function to Create or Update the employee in the database
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final mobile = _fullMobileNumber.isNotEmpty ? _fullMobileNumber : _mobileController.text;
    if (mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile number is required')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Prepare the "Envelope" of data to send to the server
      final Map<String, dynamic> data = {
        'fullName': _nameController.text,
        'email': _emailController.text,
        'mobileNumber': mobile,
        'role': _role,
        'department': _departmentController.text,
        'salary': double.tryParse(_salaryController.text) ?? 0,
        'shiftId': _selectedShiftId,
        'isActive': _isActive ? 1 : 0,
        'weekOffs': _selectedWeekOffs.join(','),
      };

      if (widget.employee == null) {
        // NEW EMPLOYEE Logic: Requires a password
        if (_passwordController.text.isEmpty) throw Exception('Password is required for new employees');
        data['password'] = _passwordController.text;
        await ApiService.createUser(data, image: _imageFile);
      } else {
        // EDIT EMPLOYEE Logic: Updates only what changed
        if (_passwordController.text.isNotEmpty) data['password'] = _passwordController.text;
        await ApiService.updateUser(widget.employee!['id'], data, image: _imageFile);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee saved successfully')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Employee' : 'Add Employee')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: PulseColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: PulseColors.primary.withOpacity(0.4), width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: PulseColors.surfaceVariant,
                              backgroundImage: _imageFile != null
                                  ? FileImage(File(_imageFile!.path))
                                  : (widget.employee?['profilePicture'] != null
                                      ? NetworkImage(ApiService.getImageUrl(widget.employee!['profilePicture']))
                                      : null) as ImageProvider?,
                              child: (_imageFile == null && widget.employee?['profilePicture'] == null)
                                  ? const Icon(Icons.camera_alt, size: 28, color: PulseColors.textHint)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: PulseColors.primary, shape: BoxShape.circle, border: Border.all(color: PulseColors.background, width: 2)),
                              child: const Icon(Icons.edit, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _field(_nameController, 'Full Name', Icons.person, validator: (v) => v!.isEmpty ? 'Required' : null),
                    const SizedBox(height: 14),
                    _field(_emailController, 'Email', Icons.email, validator: (v) => v!.isEmpty ? 'Required' : null),
                    const SizedBox(height: 14),
                    IntlPhoneField(
                      controller: _mobileController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: const Icon(Icons.phone, color: PulseColors.textHint),
                        filled: true, fillColor: PulseColors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PulseColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PulseColors.border)),
                      ),
                      initialCountryCode: 'IN',
                      onChanged: (phone) => _fullMobileNumber = phone.completeNumber,
                    ),
                    const SizedBox(height: 14),
                    _field(_passwordController, isEdit ? 'Change Password (Optional)' : 'Password', Icons.lock,
                        obscure: true,
                        validator: isEdit ? null : (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 4) return 'Min 4 characters';
                          return null;
                        }),
                    const SizedBox(height: 14),

                    // Role & Department
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _role,
                          decoration: InputDecoration(
                            labelText: 'Role',
                            filled: true, fillColor: PulseColors.surfaceVariant,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PulseColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PulseColors.border)),
                          ),
                          items: ['User', 'Admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (v) => setState(() => _role = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_departmentController, 'Department', Icons.business)),
                    ]),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<int>(
                      value: _selectedShiftId,
                      decoration: InputDecoration(
                        labelText: 'Assign Shift',
                        filled: true, fillColor: PulseColors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PulseColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PulseColors.border)),
                      ),
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('No Shift')),
                        ..._shifts.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name'] ?? 'Unnamed'))),
                      ],
                      onChanged: (v) => setState(() => _selectedShiftId = v),
                    ),
                    const SizedBox(height: 14),

                    _field(_salaryController, 'Monthly Salary (₹)', Icons.payments,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null || double.parse(v) < 0) return 'Invalid';
                          return null;
                        }),
                    const SizedBox(height: 14),

                    // Week Offs
                    PulseCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Week Offs', style: PulseTextStyles.bodyBold),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 4,
                          children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((day) {
                            final isSelected = _selectedWeekOffs.contains(day);
                            return FilterChip(
                              label: Text(day.substring(0, 3), style: TextStyle(color: isSelected ? Colors.white : PulseColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                              selected: isSelected,
                              selectedColor: PulseColors.primary,
                              backgroundColor: PulseColors.surfaceVariant,
                              checkmarkColor: Colors.white,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) { _selectedWeekOffs.add(day); } else { _selectedWeekOffs.remove(day); }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Active Toggle
                    PulseCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: SwitchListTile(
                        title: Text('Account Active', style: PulseTextStyles.bodyBold),
                        subtitle: Text(
                          _isActive ? 'Employee can log in' : 'Employee cannot log in',
                          style: PulseTextStyles.caption.copyWith(color: _isActive ? PulseColors.success : PulseColors.error),
                        ),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeColor: PulseColors.success,
                      ),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PulseColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isEdit ? 'SAVE CHANGES' : 'CREATE EMPLOYEE', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {bool obscure = false, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: PulseColors.textHint),
        filled: true, fillColor: PulseColors.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PulseColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PulseColors.border)),
      ),
    );
  }
}
