import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common/glass_card.dart';
import 'employee_form_screen.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  List<dynamic> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAllUsers();
      if (mounted) setState(() => _employees = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Employees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              final result = await Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => EmployeeFormScreen())
              );
              if (result == true) _loadEmployees();
            },
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? const Center(child: Text('No employees found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    return _buildEmployeeCard(employee);
                  },
                ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> employee) {
    final bool isActive = employee['isActive'] == 1 || employee['isActive'] == true;
    
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: employee['profilePicture'] != null 
                ? NetworkImage(ApiService.getImageUrl(employee['profilePicture']))
                : null,
              child: employee['profilePicture'] == null ? const Icon(Icons.person, size: 30) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee['fullName'] ?? 'User',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    '${employee['role'] ?? 'Employee'} | ${employee['shiftName'] ?? 'No Shift'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(employee['mobileNumber'] ?? 'N/A', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: isActive,
                  onChanged: (val) async {
                    try {
                      await ApiService.updateUser(employee['id'], {'isActive': val ? 1 : 0});
                      _loadEmployees();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  activeColor: const Color(0xFF00BFA5),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EmployeeFormScreen(employee: employee))
                        );
                        if (result == true) _loadEmployees();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(employee),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ), 
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> employee) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee['fullName']}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteUser(employee['id']);
        _loadEmployees();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee deleted.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

