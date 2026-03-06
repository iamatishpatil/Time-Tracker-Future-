import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/branding_provider.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_scaffold.dart';
import '../../widgets/admin_drawer.dart';
import '../../services/api_service.dart';
import 'admin_dashboard_screen.dart';
import 'admin_attendance_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_leaves_screen.dart';
import 'admin_settings_screen.dart';

class AdminContainer extends ConsumerStatefulWidget {
  const AdminContainer({super.key});

  @override
  ConsumerState<AdminContainer> createState() => _AdminContainerState();
}

class _AdminContainerState extends ConsumerState<AdminContainer> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getStoredUser();
    if (mounted) setState(() => _user = user);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(brandingProvider);
    
    if (_user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> screens = [
      const AdminDashboardScreen(isTab: true),
      const AdminAttendanceScreen(isTab: true),
      const AdminEmployeesScreen(isTab: true),
      const AdminLeavesScreen(isTab: true),
    ];

    final List<String> titles = [
      'Admin Dashboard',
      'Attendance Logs',
      'Employee Directory',
      'Leave Management',
    ];

    return PulseScaffold(
      title: titles[_selectedIndex],
      drawer: AdminDrawer(user: _user!, onUserUpdated: (u) => setState(() => _user = u)),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: PulseColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: PulseColors.primary.withOpacity(0.04),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Expanded(child: _buildNavItem(0, Icons.dashboard_rounded, Icons.dashboard_outlined, 'Home')),
                Expanded(child: _buildNavItem(1, Icons.history_rounded, Icons.history_outlined, 'Attendance')),
                Expanded(child: _buildNavItem(2, Icons.people_rounded, Icons.people_outline_rounded, 'Staff')),
                Expanded(child: _buildNavItem(3, Icons.beach_access_rounded, Icons.beach_access_outlined, 'Leaves')),
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
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? PulseColors.brandLight.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? PulseColors.brandPrimary : PulseColors.textHint,
                size: 20,
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: PulseTextStyles.captionBold.copyWith(
                    color: PulseColors.primary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
