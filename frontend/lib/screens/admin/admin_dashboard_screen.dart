import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/admin_drawer.dart';
import 'admin_attendance_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_leaves_screen.dart';
import 'admin_absent_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic> _stats = {
    'totalEmployees': 0,
    'presentToday': 0,
    'absentToday': 0,
    'onLeaveToday': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService.getStoredUser();
      final stats = await ApiService.getAdminStats();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _stats = stats;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateUser(Map<String, dynamic> updatedUser) {
    setState(() => _currentUser = updatedUser);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: _currentUser != null 
          ? AdminDrawer(user: _currentUser!, onUserUpdated: _updateUser) 
          : null,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Stats Grid
                   GridView.count(
                     crossAxisCount: 2,
                     crossAxisSpacing: 16,
                     mainAxisSpacing: 16,
                     shrinkWrap: true,
                     physics: const NeverScrollableScrollPhysics(),
                     children: [
                       _buildStatCard('Total Employees', _stats['totalEmployees'].toString(), Colors.blue, Icons.people, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEmployeesScreen()))),
                       _buildStatCard('Present Today', _stats['presentToday'].toString(), Colors.green, Icons.check_circle),
                       _buildStatCard('Absent Today', _stats['absentToday'].toString(), Colors.red, Icons.cancel, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAbsentScreen()))),
                       _buildStatCard('On Leave', _stats['onLeaveToday'].toString(), Colors.orange, Icons.beach_access, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLeavesScreen()))),
                     ],
                   ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
