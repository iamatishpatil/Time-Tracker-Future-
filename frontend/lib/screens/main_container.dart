import 'package:flutter/material.dart';
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
  List<dynamic> _history = []; // Keep history here for PDF export

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

  // Update user data when profile is edited
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
      'Attendance History',
      'Leave Management',
      'My Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_selectedIndex == 1 && _history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: () => PdfService.generateAttendanceReport(_user!['fullName'] ?? 'User', _history),
            ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: CustomDrawer(user: _user!),
      body: screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF6200EA),
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
              BottomNavigationBarItem(icon: Icon(Icons.beach_access_rounded), label: 'Leave'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
