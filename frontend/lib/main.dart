import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_attendance_screen.dart';
import 'screens/admin/admin_employees_screen.dart';
import 'screens/admin/admin_leaves_screen.dart';
import 'screens/attendance_history_screen.dart';
import 'screens/leave_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/main_container.dart';
import 'screens/notification_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const TimeTrackerApp());
}

class TimeTrackerApp extends StatelessWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Time Tracker',
      theme: ThemeData(
        useMaterial3: true,
        // Pro Color Scheme: Deep Purple & Electric Blue
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EA), // Deep Purple Accent
          primary: const Color(0xFF6200EA),
          secondary: const Color(0xFF00BFA5), // Teal Accent
          tertiary: const Color(0xFF2962FF), // Electric Blue
          surface: const Color(0xFFF3E5F5), // Very light purple tint
          background: const Color(0xFFF3E5F5),
          error: const Color(0xFFD32F2F),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3E5F5),
        
        // Typography - Modern & Clean
        textTheme: GoogleFonts.outfitTextTheme(
          Typography.material2021().black,
        ).apply(
          bodyColor: const Color(0xFF1A1A1D), 
          displayColor: const Color(0xFF1A1A1D),
        ),
        
        // Component Themes
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF311B92), // Deep Indigo
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF311B92)),
        ),
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6200EA),
            foregroundColor: Colors.white,
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6200EA), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF5E35B1)),
          prefixIconColor: const Color(0xFF5E35B1),
        ),
        
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: const Color(0xFF6200EA).withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: Colors.white,
        ),

        iconTheme: const IconThemeData(
          color: Color(0xFF6200EA),
          size: 24,
        ),
      ),
      // Rely on 'home' logic for initial entry point

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
                return MainContainer(); // Now profile is part of navigation
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
            return MainContainer(); // Use the new container
          }
          return LoginScreen();
        },
      ),
    );
  }
}
