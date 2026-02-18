import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common/glass_card.dart';

class AdminLeavesScreen extends StatefulWidget {
  const AdminLeavesScreen({super.key});

  @override
  State<AdminLeavesScreen> createState() => _AdminLeavesScreenState();
}

class _AdminLeavesScreenState extends State<AdminLeavesScreen> {
  List<dynamic> _leaves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAllLeaves();
      if (mounted) setState(() => _leaves = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await ApiService.updateLeaveStatus(id, status);
      _loadLeaves();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Management')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _leaves.isEmpty
              ? const Center(child: Text('No leave requests found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _leaves.length,
                  itemBuilder: (context, index) {
                    final leave = _leaves[index];
                    return _buildLeaveCard(leave);
                  },
                ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final status = leave['status'] ?? 'Pending';
    final color = status == 'Approved' ? Colors.green : (status == 'Rejected' ? Colors.red : Colors.orange);
    
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: leave['profilePicture'] != null 
                    ? NetworkImage(ApiService.getImageUrl(leave['profilePicture']))
                    : null,
                  child: leave['profilePicture'] == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(leave['fullName'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(leave['leaveType'] ?? 'Leave', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text('${leave['startDate']} to ${leave['endDate']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(leave['reason'] ?? 'No reason provided', style: TextStyle(color: Colors.grey[700], fontSize: 12))),
              ],
            ),
            if (status == 'Pending') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _updateStatus(leave['id'], 'Rejected'),
                    child: const Text('REJECT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _updateStatus(leave['id'], 'Approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      minimumSize: const Size(80, 36),
                    ),
                    child: const Text('APPROVE'),
                  ),
                ],
              ),
            ],
          ],
        ), // Column
    );
  }
}
