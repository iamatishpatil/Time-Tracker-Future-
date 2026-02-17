import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CustomDrawer extends StatelessWidget {
  final Map<String, dynamic> user;

  const CustomDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user['fullName'] ?? 'User'),
            accountEmail: Text(
              user['role'] != null ? '${user['email'] ?? ''}\n${user['role']}' : (user['email'] ?? ''),
              style: const TextStyle(fontSize: 12),
            ),
            currentAccountPicture: Stack(
              children: [
                CircleAvatar(
                  backgroundImage: user['profilePicture'] != null 
                      ? NetworkImage('http://192.168.1.33:3000${user['profilePicture']}')
                      : null,
                  child: user['profilePicture'] == null ? const Icon(Icons.person) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.pushNamed(context, '/edit-profile');
                      // Reload user data after returning from edit profile
                      final updatedUser = await ApiService.getStoredUser();
                      if (updatedUser != null && context.mounted) {
                        // Force rebuild of parent widget
                        if (Navigator.of(context).canPop()) {
                          Navigator.pushReplacementNamed(context, '/home');
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6200EA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6200EA), Color(0xFF651FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Color(0xFF6200EA)),
            title: const Text('User Details'),
            onTap: () {
              Navigator.pop(context);
              _showUserDetailsDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Attendance History'),
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          ListTile(
            leading: const Icon(Icons.beach_access),
            title: const Text('Apply Leave'),
            onTap: () => Navigator.pushNamed(context, '/leave'),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ApiService.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showUserDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('User Details', style: TextStyle(color: Color(0xFF6200EA), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Full Name', user['fullName']),
              _buildDetailRow('Email', user['email']),
              _buildDetailRow('Mobile', user['mobileNumber']),
              _buildDetailRow('Gender', user['gender']),
              _buildDetailRow('Role', user['role']),
              _buildDetailRow('Company', user['company']),
              _buildDetailRow('Department', user['department']),
              _buildDetailRow('Experience', user['experience']),
              _buildDetailRow('Technologies', user['technologies']),
              _buildDetailRow('Address', user['address']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
