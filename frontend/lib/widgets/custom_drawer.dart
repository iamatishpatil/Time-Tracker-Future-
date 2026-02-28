import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../services/api_service.dart';
import '../core/widgets/branded_logo.dart';

import '../core/widgets/branded_background.dart';

class CustomDrawer extends StatelessWidget {
  final Map<String, dynamic> user;

  const CustomDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: PulseColors.surface,
      child: BrandedBackground(
        child: Column(
          children: [
            // Profile Header
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
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/edit-profile');
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: PulseColors.surfaceVariant,
                              backgroundImage: user['profilePicture'] != null
                                  ? CachedNetworkImageProvider(ApiService.getImageUrl(user['profilePicture']))
                                  : null,
                              child: user['profilePicture'] == null
                                  ? const Icon(Icons.person, size: 32, color: PulseColors.textHint)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 3,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: PulseColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      BrandedLogo(size: 50, showText: false),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user['fullName'] ?? 'User',
                    style: PulseTextStyles.h3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['email'] ?? '',
                    style: PulseTextStyles.caption,
                  ),
                  if (user['role'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: PulseColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user['role'],
                        style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primary),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Menu Items
            _DrawerTile(
              icon: Icons.person_outline_rounded,
              title: 'User Details',
              onTap: () {
                Navigator.pop(context);
                _showUserDetailsDialog(context);
              },
            ),
            _DrawerTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/change-password');
              },
            ),
            _DrawerTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/notifications');
              },
            ),
            _DrawerTile(
              icon: Icons.calendar_today_outlined,
              title: 'Holidays',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/user-holidays');
              },
            ),
            _DrawerTile(
              icon: Icons.schedule,
              title: 'Company Shifts',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/user-shifts');
              },
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: ApiService.getSettings(),
              builder: (context, snapshot) {
                final payrollEnabled = snapshot.data?['payrollEnabled'] != 0;
                if (payrollEnabled) {
                  return _DrawerTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'My Payslips',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/user-payslips');
                    },
                  );
                }
                return const SizedBox.shrink();
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

  void _showUserDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Name', user['fullName'] ?? 'N/A'),
            _detailRow('Email', user['email'] ?? 'N/A'),
            _detailRow('Mobile', user['mobileNumber'] ?? 'N/A'),
            _detailRow('Role', user['role'] ?? 'N/A'),
            _detailRow('Department', user['department'] ?? 'N/A'),
            _detailRow('Gender', user['gender'] ?? 'N/A'),
            if (user['shiftName'] != null)
              _detailRow('Shift', '${user['shiftName']} (${user['shiftStart']} - ${user['shiftEnd']})')
            else
              _detailRow('Shift', 'Not Assigned'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: PulseTextStyles.caption),
          ),
          Expanded(
            child: Text(value, style: PulseTextStyles.bodyBold.copyWith(fontSize: 14)),
          ),
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

