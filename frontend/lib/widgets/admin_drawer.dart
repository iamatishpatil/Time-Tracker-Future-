import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminDrawer extends StatelessWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;

  const AdminDrawer({super.key, required this.user, required this.onUserUpdated});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user['fullName'] ?? 'Admin'),
            accountEmail: Text(user['email'] ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundImage: user['profilePicture'] != null 
                  ? NetworkImage(ApiService.getImageUrl(user['profilePicture']))
                  : null,
              child: user['profilePicture'] == null ? const Icon(Icons.person) : null,
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
            leading: const Icon(Icons.dashboard, color: Color(0xFF6200EA)),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/admin');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFF6200EA)),
            title: const Text('View All Attendance'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin-attendance');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_alt_outlined, color: Color(0xFF6200EA)),
            title: const Text('Manage Employees'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin-employees');
            },
          ),
          ListTile(
            leading: const Icon(Icons.beach_access_outlined, color: Color(0xFF6200EA)),
            title: const Text('Leave Management'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin-leaves');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Color(0xFF6200EA)),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin-settings');
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () async {
                        await ApiService.logout();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        }
                      },
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
