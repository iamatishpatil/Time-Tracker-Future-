// --- 1. The Main Shell (Container) ---
// This file is like a "Cabinet". It stays on the screen, but it has 4 "drawers" 
// (Tabs) that we can open and close.

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
import '../core/widgets/pulse_scaffold.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  // --- The Brain of the Navigation ---
  int _selectedIndex = 0; // Keeps track of which tab is currently open (0 to 3)
  Map<String, dynamic>? _user; // Stores the logged-in user's info
  List<dynamic> _history = []; // Stores the user's attendance records

  @override
  void initState() {
    super.initState();
    _loadUser(); // Load data as soon as the cabinet opens!
  }

  // Fetch the user and their history from the server/vault
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

  // If the user updates their profile, we need to refresh the info here too
  void _updateUser(Map<String, dynamic> updatedUser) {
    setState(() => _user = updatedUser);
  }

  @override
  Widget build(BuildContext context) {
    // Show a spinner while we wait for the user's data to load
    if (_user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // --- The 4 Drawers (Screens) ---
    final List<Widget> screens = [
      const HomeScreen(), // Tab 0
      const AttendanceHistoryScreen(), // Tab 1
      const LeaveScreen(), // Tab 2
      EditProfileScreen(user: _user!, onUserUpdated: _updateUser), // Tab 3
    ];

    // The titles that appear at the top of the app bar
    final List<String> titles = [
      'Dashboard',
      'Attendance',
      'Leaves',
      'Profile',
    ];

    return PulseScaffold(
      title: titles[_selectedIndex],
      actions: [
        if (_selectedIndex == 1 && _history.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
            tooltip: 'Download Report',
            onPressed: () => PdfService.generateAttendanceReport(
                _user!['fullName'] ?? 'User', _history),
          ),
        const SizedBox(width: 8),
      ],
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

  // A helper function to build each button in the bottom bar
  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index), // Change tab on tap
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // Add a subtle glow/background when selected
          color: isSelected ? PulseColors.brandLight.withOpacity(0.5) : Colors.transparent,
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
            // Show the text label ONLY if this tab is selected
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
