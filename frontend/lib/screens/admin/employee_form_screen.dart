import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../widgets/common/glass_card.dart';

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

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameController = TextEditingController(text: e?['fullName'] ?? '');
    _emailController = TextEditingController(text: e?['email'] ?? '');
    _mobileController = TextEditingController(text: e?['mobileNumber'] ?? '');
    _passwordController = TextEditingController();
    _salaryController = TextEditingController(text: (e?['salary'] ?? 0).toString());
    _departmentController = TextEditingController(text: e?['department'] ?? 'General');
    _role = e?['role'] ?? 'User';
    _selectedShiftId = e?['shiftId'];
    _isActive = e == null ? true : (e['isActive'] == 1 || e['isActive'] == true);
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    try {
      final shifts = await ApiService.getShifts();
      setState(() => _shifts = shifts);
    } catch (e) {
      debugPrint('Error loading shifts: $e');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> data = {
        'fullName': _nameController.text,
        'email': _emailController.text,
        'mobileNumber': _mobileController.text,
        'role': _role,
        'department': _departmentController.text,
        'salary': double.tryParse(_salaryController.text) ?? 0,
        'shiftId': _selectedShiftId,
        'isActive': _isActive ? 1 : 0,
      };

      if (widget.employee == null) {
        // Add mode
        if (_passwordController.text.isEmpty) {
          throw Exception('Password is required for new employees');
        }
        data['password'] = _passwordController.text;
        await ApiService.createUser(data, image: _imageFile);
      } else {
        // Edit mode
        if (_passwordController.text.isNotEmpty) {
          data['password'] = _passwordController.text;
        }
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
    final isEdit = widget.employee != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Employee' : 'Add Employee')),
      body: _isLoading 
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
                        radius: 50,
                        backgroundImage: _imageFile != null 
                            ? FileImage(File(_imageFile!.path)) 
                            : (widget.employee?['profilePicture'] != null 
                                ? NetworkImage(ApiService.getImageUrl(widget.employee!['profilePicture']))
                                : null) as ImageProvider?,
                        child: (_imageFile == null && widget.employee?['profilePicture'] == null) 
                            ? const Icon(Icons.camera_alt, size: 30) 
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Change Password (Optional)' : 'Password',
                        border: const OutlineInputBorder()
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _role,
                            decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                            items: ['User', 'Admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                            onChanged: (v) => setState(() => _role = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _departmentController,
                            decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedShiftId,
                      decoration: const InputDecoration(labelText: 'Assign Shift', border: OutlineInputBorder()),
                      items: _shifts.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text(s['name']))).toList(),
                      onChanged: (v) => setState(() => _selectedShiftId = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _salaryController,
                      decoration: const InputDecoration(labelText: 'Monthly Salary (₹)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Account Active'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeColor: Colors.green,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isEdit ? 'SAVE CHANGES' : 'CREATE EMPLOYEE'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
