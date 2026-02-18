import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../services/csv_service.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/admin_drawer.dart';
import 'admin_attendance_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_leaves_screen.dart';
import 'admin_payroll_screen.dart';
import 'admin_settings_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _user;
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
          _user = user;
          _stats = stats;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Command Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: _user != null ? AdminDrawer(user: _user!, onUserUpdated: (u) => setState(() => _user = u)) : null,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Operational Overview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF311B92)),
                  ),
                  const SizedBox(height: 16),
                  
                  // Performance Grid
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStatCard(
                        'Total Staff', 
                        _stats?['totalEmployees']?.toString() ?? '0', 
                        Colors.blue, 
                        Icons.people,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEmployeesScreen())),
                      ),
                      _buildStatCard(
                        'Present Now', 
                        _stats?['presentToday']?.toString() ?? '0', 
                        Colors.green, 
                        Icons.check_circle,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAttendanceScreen())),
                      ),
                      _buildStatCard(
                        'Late Today', 
                        _stats?['lateToday']?.toString() ?? '0', 
                        Colors.orange, 
                        Icons.timer,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAttendanceScreen())),
                      ),
                      _buildStatCard(
                        'Absent', 
                        _stats?['absentToday']?.toString() ?? '0', 
                        Colors.red, 
                        Icons.cancel,
                        onTap: () => Navigator.pushNamed(context, '/admin-absent'),
                      ),
                      _buildStatCard(
                        'On Leave', 
                        _stats?['onLeaveToday']?.toString() ?? '0', 
                        Colors.purple, 
                        Icons.beach_access,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLeavesScreen())),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  const Text(
                    'Management Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF311B92)),
                  ),
                  const SizedBox(height: 16),
                  
                  // Quick Actions Grid
                  GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildActionCard('Employees', Icons.person_add, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEmployeesScreen()))),
                      _buildActionCard('Attendance', Icons.history, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAttendanceScreen()))),
                      _buildActionCard('Leaves', Icons.beach_access, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLeavesScreen()))),
                      _buildActionCard('Payroll', Icons.payments, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPayrollScreen()))),
                      _buildActionCard('Reports', Icons.assessment, Colors.teal, () => Navigator.pushNamed(context, '/admin-reports')),
                      _buildActionCard('Settings', Icons.settings, Colors.grey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen()))),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon, {VoidCallback? onTap}) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
