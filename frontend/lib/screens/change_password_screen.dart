import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
        return;
      }

      setState(() => _isLoading = true);
      try {
        final user = await ApiService.getStoredUser();
        if (user != null) {
          await ApiService.changePassword(user['id'], _oldPasswordController.text, _newPasswordController.text);
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully!')));
             Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _oldPasswordController,
                decoration: const InputDecoration(labelText: 'Old Password', border: OutlineInputBorder()),
                obscureText: true,
                validator: (v) => v!.isEmpty ? 'Enter old password' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                obscureText: true,
                validator: (v) => v!.length < 6 ? 'Password must be at least 6 chars' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
                obscureText: true,
                validator: (v) => v!.isEmpty ? 'Confirm password' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA), foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('CHANGE PASSWORD'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
