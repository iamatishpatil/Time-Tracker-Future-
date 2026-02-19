import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/pulse_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_attendance_screen.dart';
import 'screens/admin/admin_employees_screen.dart';
import 'screens/admin/admin_leaves_screen.dart';
import 'screens/admin/admin_reports_screen.dart';
import 'screens/attendance_history_screen.dart';
import 'screens/leave_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/main_container.dart';
import 'screens/notification_screen.dart';
import 'screens/user_holidays_screen.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A2E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TimeTrackerApp());
}

class TimeTrackerApp extends StatelessWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Time Tracker',
      theme: PulseTheme.dark(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const MainContainer(),
        '/history': (context) => const AttendanceHistoryScreen(),
        '/leave': (context) => const LeaveScreen(),
        '/admin': (context) => AdminDashboardScreen(),
        '/admin-attendance': (context) => AdminAttendanceScreen(),
        '/admin-employees': (context) => AdminEmployeesScreen(),
        '/admin-leaves': (context) => AdminLeavesScreen(),
        '/edit-profile': (context) {
          return FutureBuilder(
            future: ApiService.getStoredUser(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData && snapshot.data != null) {
                return MainContainer();
              }
              return const Scaffold(
                body: Center(child: Text('Unable to load user data')),
              );
            },
          );
        },
        '/change-password': (context) => ChangePasswordScreen(),
        '/notifications': (context) => NotificationScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/user-holidays': (context) => const UserHolidaysScreen(),
        '/admin-reports': (context) => const AdminReportsScreen(),
      },
      home: FutureBuilder(
        future: ApiService.getStoredUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null) {
            final user = snapshot.data as Map<String, dynamic>;
            if (user['role'] == 'Admin') {
              return AdminDashboardScreen();
            }
            return MainContainer();
          }
          return LoginScreen();
        },
      ),
    );
  }
}
