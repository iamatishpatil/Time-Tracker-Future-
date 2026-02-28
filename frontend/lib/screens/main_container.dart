// --- Main Shell (Container) ---
// Stays on screen; swaps content via indexed tab system.
// ANR Fix: Removed serial history fetch from initState. History is now loaded
// lazily by AttendanceHistoryScreen itself. The container only loads the user
// profile (fast, from SharedPreferences) which prevents the startup spinner.

import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import 'home_screen.dart';
import 'attendance_history_screen.dart';
import 'leave_screen.dart';
import 'edit_profile_screen.dart';
import '../services/api_service.dart';
import '../widgets/custom_drawer.dart';
import '../core/widgets/pulse_scaffold.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  // ANR Fix: Only fetches user from local SharedPreferences (instant).
  // No heavy API call here that would block the UI spinner.
  Future<void> _loadUser() async {
    final user = await ApiService.getStoredUser();
    if (mounted) setState(() => _user = user);
  }

  void _updateUser(Map<String, dynamic> updatedUser) {
    if (mounted) setState(() => _user = updatedUser);
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<String> titles = ['Dashboard', 'Attendance', 'Leaves', 'Profile'];

    // ANR Fix: Using IndexedStack keeps all screens alive, avoiding
    // re-creation and redundant network calls on every tab switch.
    return PulseScaffold(
      title: titles[_selectedIndex],
      drawer: CustomDrawer(user: _user!),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const HomeScreen(),
          const AttendanceHistoryScreen(),
          const LeaveScreen(),
          EditProfileScreen(user: _user!, onUserUpdated: _updateUser),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: PulseColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: PulseColors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, Icons.dashboard_outlined, 'Home'),
                _buildNavItem(1, Icons.history_rounded, Icons.history_outlined, 'History'),
                _buildNavItem(2, Icons.beach_access_rounded, Icons.beach_access_outlined, 'Leave'),
                _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? PulseColors.brandLight.withValues(alpha: 0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? PulseColors.brandPrimary : PulseColors.textHint,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
