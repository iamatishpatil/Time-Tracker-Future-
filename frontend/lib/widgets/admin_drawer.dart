import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../services/api_service.dart';
import '../screens/edit_profile_screen.dart';

class AdminDrawer extends StatelessWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;

  const AdminDrawer({super.key, required this.user, required this.onUserUpdated});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: PulseColors.surface,
      child: Column(
        children: [
          // Admin Profile Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF252540)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: PulseColors.surfaceVariant,
                  backgroundImage: user['profilePicture'] != null
                      ? NetworkImage(ApiService.getImageUrl(user['profilePicture']))
                      : null,
                  child: user['profilePicture'] == null
                      ? const Icon(Icons.admin_panel_settings, size: 28, color: PulseColors.primary)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(user['fullName'] ?? 'Admin', style: PulseTextStyles.h3),
                const SizedBox(height: 4),
                Text(user['email'] ?? '', style: PulseTextStyles.caption),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PulseColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ADMIN',
                    style: PulseTextStyles.captionBold.copyWith(color: PulseColors.accent),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          _DrawerTile(
            icon: Icons.dashboard_rounded,
            title: 'Dashboard',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/admin');
            },
          ),
          _DrawerTile(
            icon: Icons.person_outline,
            title: 'Profile Settings',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    user: user,
                    onUserUpdated: onUserUpdated,
                  ),
                ),
              );
            },
          ),
          _DrawerTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/notifications');
            },
          ),

          const Spacer(),
          const Divider(color: PulseColors.divider),
          _DrawerTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            isDestructive: true,
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
                      child: Text('Logout', style: TextStyle(color: PulseColors.error)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? PulseColors.error : PulseColors.textSecondary;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: PulseTextStyles.body.copyWith(
          color: isDestructive ? PulseColors.error : PulseColors.textPrimary,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    );
  }
}
