import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class AdminAbsentScreen extends StatefulWidget {
  const AdminAbsentScreen({super.key});

  @override
  State<AdminAbsentScreen> createState() => _AdminAbsentScreenState();
}

class _AdminAbsentScreenState extends State<AdminAbsentScreen> {
  List<dynamic> _absentEmployees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAbsent();
  }

  Future<void> _loadAbsent() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAbsentEmployees();
      if (mounted) setState(() => _absentEmployees = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Absent Today')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _absentEmployees.isEmpty
              ? const Center(child: Text('No absences reported today.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _absentEmployees.length,
                  itemBuilder: (context, index) {
                    final employee = _absentEmployees[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: employee['profilePicture'] != null 
                              ? NetworkImage(ApiService.getImageUrl(employee['profilePicture']))
                              : null,
                          child: employee['profilePicture'] == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(employee['fullName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(employee['mobileNumber'] ?? ''),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Absent', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
