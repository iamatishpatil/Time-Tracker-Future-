import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import 'home_screen.dart';
import 'attendance_history_screen.dart';
import 'leave_screen.dart';
import 'edit_profile_screen.dart';
import '../services/api_service.dart';
import '../widgets/custom_drawer.dart';
import '../services/pdf_service.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _user;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getStoredUser();
    if (user != null) {
      final history = await ApiService.getAttendance(user['id']);
      setState(() {
        _user = user;
        _history = history;
      });
    }
  }

  void _updateUser(Map<String, dynamic> updatedUser) {
    setState(() => _user = updatedUser);
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> screens = [
      const HomeScreen(),
      const AttendanceHistoryScreen(),
      const LeaveScreen(),
      EditProfileScreen(user: _user!, onUserUpdated: _updateUser),
    ];

    final List<String> titles = [
      'Dashboard',
      'Attendance',
      'Leaves',
      'Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          if (_selectedIndex == 1 && _history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              onPressed: () => PdfService.generateAttendanceReport(
                  _user!['fullName'] ?? 'User', _history),
            ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: CustomDrawer(user: _user!),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: PulseColors.surface,
          border: Border(
            top: BorderSide(color: PulseColors.border, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
          color: isSelected ? PulseColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? PulseColors.primary : PulseColors.textHint,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: PulseTextStyles.captionBold.copyWith(
                  color: PulseColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
