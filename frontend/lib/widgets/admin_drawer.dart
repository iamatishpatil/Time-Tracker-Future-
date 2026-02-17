import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../screens/edit_profile_screen.dart';

class AdminDrawer extends StatelessWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;

  const AdminDrawer({super.key, required this.user, required this.onUserUpdated});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user['fullName'] ?? 'Admin'),
            accountEmail: Text(user['email'] ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundImage: user['profilePicture'] != null 
                  ? NetworkImage('http://192.168.1.33:3000${user['profilePicture']}')
                  : null,
              child: user['profilePicture'] == null ? const Icon(Icons.person) : null,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF6200EA),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context); // Close drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: user, onUserUpdated: onUserUpdated)));
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text('Quick Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.blue),
            title: const Text('View All Attendance'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin-attendance');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline, color: Colors.purple),
            title: const Text('Manage Employees'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin-employees');
            },
          ),
          ListTile(
            leading: const Icon(Icons.beach_access_outlined, color: Colors.orange),
            title: const Text('Leave Management'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin-leaves');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              // Show confirmation
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
        ],
      ),
    );
  }
}
