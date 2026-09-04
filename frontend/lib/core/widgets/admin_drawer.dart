import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/pulse_colors.dart';
import 'package:frontend/core/theme/pulse_text_styles.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/features/profile/screens/edit_profile_screen.dart';
import 'package:frontend/core/widgets/branded_logo.dart';
import 'package:frontend/core/widgets/branded_background.dart';

class AdminDrawer extends StatelessWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;

  const AdminDrawer({super.key, required this.user, required this.onUserUpdated});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: PulseColors.surface,
      child: BrandedBackground(
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [PulseColors.surface, PulseColors.primary.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: PulseColors.surfaceVariant,
                      backgroundImage: user['profilePicture'] != null
                          ? CachedNetworkImageProvider(ApiService.getImageUrl(user['profilePicture']))
                          : null,
                      child: user['profilePicture'] == null
                          ? Icon(Icons.admin_panel_settings, size: 28, color: PulseColors.primary)
                          : null,
                    ),
                    BrandedLogo(size: 50, showText: false),
                  ],
                ),
                const SizedBox(height: 16),
                Text(user['fullName'] ?? 'Admin', style: PulseTextStyles.h3),
                const SizedBox(height: 4),
                Text(user['email'] ?? '', style: PulseTextStyles.caption),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PulseColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ADMIN',
                    style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),


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
          FutureBuilder<Map<String, dynamic>>(
            future: ApiService.getSettings(),
            builder: (context, snapshot) {
              final payrollEnabled = snapshot.data?['payrollEnabled'] != 0;
              if (payrollEnabled) {
                return _DrawerTile(
                  icon: Icons.payments_outlined,
                  title: 'Payslips',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/admin-payslips');
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),

          _DrawerTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin-settings');
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: PulseColors.primary.withOpacity(0.06),
          highlightColor: PulseColors.primary.withOpacity(0.03),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDestructive ? PulseColors.error : PulseColors.primary).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: PulseTextStyles.body.copyWith(
                      color: isDestructive ? PulseColors.error : PulseColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!isDestructive)
                  Icon(Icons.chevron_right_rounded, color: PulseColors.textHint.withOpacity(0.5), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

