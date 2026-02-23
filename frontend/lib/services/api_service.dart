// --- 1. The API Bridge (Service Layer) ---
// This file is like a "postman". Its only job is to take data from our 
// Flutter screens and "deliver" it to the server, then bring back the answer.

import 'dart:convert'; // Converts text/json into stuff Dart understand
import 'package:http/http.dart' as http; // The tool we use to talk to the internet
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Local storage (like a tiny vault)
import 'package:intl/intl.dart';

class ApiService {
  // --- The Server Address ---
  // Every server has an address (IP). We use this to tell Flutter where to send data.
  static String get baseUrl {
    return 'http://192.168.4.21:3000/api';
  }

  // Helper to get full URLs for images stored on the server
  static String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return baseUrl.replaceAll('/api', '') + path;
  }

  // A private helper to find out which company the current user belongs to
  static Future<String?> _getCompany() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      try {
        final user = json.decode(userStr);
        return user['company'];
      } catch (_) {}
    }
    return null;
  }

  // --- Registration Logic ---
  static Future<Map<String, dynamic>> register(Map<String, String> fields, XFile? image) async {
    var uri = Uri.parse('$baseUrl/register');
    
    // MultipartRequest is used when we need to upload FILES (like a photo)
    var request = http.MultipartRequest('POST', uri);
    
    // Add all the text data (name, email, etc.)
    request.fields.addAll(fields);
    
    // If there is a photo, attach it to the request "package"
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('profilePicture', image.path));
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return json.decode(response.body); // Server says YES!
      } else {
        // Server said NO, let's find out why (e.g., email already exists)
        String errorMessage = 'Failed to register';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) errorMessage = errorData['error'];
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- Login Logic ---
  static Future<Map<String, dynamic>> login(String mobileNumber, String password) async {
    try {
      // http.post sends a standard "package" of data to the server
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'mobileNumber': mobileNumber, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // --- IMPORTANT: Session Persistence ---
        // We save the user's data in the phone's memory (SharedPreferences)
        // so the app remembers they are logged in even if they close it.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(data['user']));
        
        return data;
      } else {
        String errorMessage = 'Failed to login';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) errorMessage = errorData['error'];
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- Auto-Login Check ---
  // When the app starts, we check the "vault" to see if a user is already there.
  static Future<Map<String, dynamic>?> getStoredUser() async {
     final prefs = await SharedPreferences.getInstance();
     String? userStr = prefs.getString('user');
     if (userStr != null) {
       return json.decode(userStr);
     }
     return null; // Vault is empty, user must login
  }

  // ========== UPDATE USER METHOD ==========
  // Update user details
  // Parameters:
  //   - userId: ID of the user to update
  //   - fields: Map of fields to update
  // Returns: Updated user map
  static Future<Map<String, dynamic>> updateUser(int userId, Map<String, dynamic> fields, {XFile? image}) async {
    final company = await _getCompany();
    if (company != null) fields['company'] = company;

    var uri = Uri.parse('$baseUrl/user/$userId');
    var request = http.MultipartRequest('PUT', uri);
    
    // Add all text fields to the request
    fields.forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });

    // If profile picture is provided, add it to the request
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('profilePicture', image.path));
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Update local storage ONLY if the updated user is the currently logged-in user
        final prefs = await SharedPreferences.getInstance();
        final currentUserStr = prefs.getString('user');
        if (currentUserStr != null) {
          final Map<String, dynamic> currentLoggedUser = json.decode(currentUserStr);
          if (currentLoggedUser['id'] == userId) {
            await prefs.setString('user', json.encode(data['user']));
          }
        }
        return data['user'];
      } else {
        throw Exception('Failed to update user: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  // --- Attendance: Check-In & Check-Out ---
  // These methods report the user's location and a selfie to the server.
  static Future<void> checkIn(int userId, {double? lat, double? long, String? address, XFile? photo}) async {
    var uri = Uri.parse('$baseUrl/checkin');
    var request = http.MultipartRequest('POST', uri);
    
    request.fields['userId'] = userId.toString();
    if (lat != null) request.fields['lat'] = lat.toString();
    if (long != null) request.fields['long'] = long.toString();
    if (address != null) request.fields['address'] = address;

    if (photo != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        String errorMessage = 'Failed to check in';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) errorMessage = errorData['error'];
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
       throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<void> checkOut(int userId, {double? lat, double? long, String? address, XFile? photo}) async {
    var uri = Uri.parse('$baseUrl/checkout');
    var request = http.MultipartRequest('POST', uri);
    
    request.fields['userId'] = userId.toString();
    if (lat != null) request.fields['lat'] = lat.toString();
    if (long != null) request.fields['long'] = long.toString();
    if (address != null) request.fields['address'] = address;

    if (photo != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        String errorMessage = 'Failed to check out';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) errorMessage = errorData['error'];
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
       throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- Fetching Attendance Data ---
  static Future<List<dynamic>> getAttendance(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/attendance/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load attendance');
    }
  }

  // Checks if the user is currently "on the clock"
  static Future<bool> getCheckInStatus(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/attendance/status/$userId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['isCheckedIn'] ?? false;
    }
    return false;
  }
  
  // Clear the phone's memory to log the user out
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
  }

  // --- OTP & Password Recovery ---

  // Send OTP
  static Future<Map<String, dynamic>> sendOtp({String? mobileNumber, String? email}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'mobileNumber': mobileNumber,
        'email': email,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to send OTP: ${response.body}');
    }
  }

  // Verify OTP
  static Future<Map<String, dynamic>> verifyOtp({String? mobileNumber, String? email, required String otp}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'mobileNumber': mobileNumber,
        'email': email,
        'otp': otp,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to verify OTP: ${response.body}');
    }
  }

  // Reset Password
  static Future<void> resetPassword(String mobileNumber, String otp, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'mobileNumber': mobileNumber,
        'otp': otp,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reset password: ${response.body}');
    }
  }

  // --- Password Management ---
  static Future<void> changePassword(int userId, String oldPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/change-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to change password';
      throw Exception(error);
    }
  }

  // --- Leave Management (User Side) ---
  // Apply for leave (Sick leave, Casual leave, etc.)
  static Future<void> applyLeave(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/leaves/apply'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to apply for leave: ${response.body}');
    }
  }

  // Get a list of all leaves the CURRENT user has applied for
  static Future<List<dynamic>> getLeaveHistory(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/leaves/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load leave history');
    }
  }

  // Cancel a leave request that hasn't started yet
  static Future<void> cancelLeave(int leaveId, int userId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/leaves/$leaveId/cancel'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to cancel leave';
      throw Exception(error);
    }
  }

  // Find out how many leave days are LEFT for the user (e.g., 10 Sick leaves remaining)
  static Future<Map<String, dynamic>> getLeaveBalance(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/leaves/balance/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load leave balance');
    }
  }

  // Get a list of the types of leave allowed by the company
  static Future<List<String>> getLeaveTypes() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await http.get(Uri.parse('$baseUrl/leaves/types$qs'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((e) => e.toString()).toList();
    } else {
      // Default list if the server request fails
      return ['Sick Leave', 'Casual Leave', 'Earned Leave'];
    }
  }

  // ============ ADMIN METHODS ============

  // --- Admin: Metrics & Reports ---
  // Get counts for the dashboard (e.g., Total Employees: 50, Present: 40)
  static Future<Map<String, dynamic>> getAdminStats() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await http.get(Uri.parse('$baseUrl/admin/stats$qs'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load admin stats');
    }
  }

  // Get a list of ALL employees in the company
  static Future<List<dynamic>> getAllUsers() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await http.get(Uri.parse('$baseUrl/admin/users$qs'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  // Find employees who didn't show up today
  static Future<List<dynamic>> getAbsentEmployees() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await http.get(Uri.parse('$baseUrl/admin/absent$qs'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load absent employees');
    }
  }

  // --- Admin: Advanced Attendance & User Management ---
  // Get all records, but with options to filter by date, user, or department
  static Future<List<dynamic>> getAllAttendance({int? userId, DateTime? startDate, DateTime? endDate, String? department}) async {
    final params = <String, String>{};
    if (userId != null) params['userId'] = userId.toString();
    if (startDate != null) params['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
    if (endDate != null) params['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
    if (department != null) params['department'] = department;
    
    final company = await _getCompany();
    if (company != null) params['company'] = company;

    final uri = Uri.parse('$baseUrl/admin/attendance').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load attendance records');
    }
  }

  // Admin can change an employee's check-in/out time if they made a mistake
  static Future<void> updateAttendance(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/attendance/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to update attendance';
      throw Exception(error);
    }
  }

  // Admin can manually add an attendance entry for someone
  static Future<void> createManualAttendance(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to create attendance';
      throw Exception(error);
    }
  }

  // Get ALL leave requests from EVERYONE for a manager to approve
  static Future<List<dynamic>> getAllLeaves() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await http.get(Uri.parse('$baseUrl/admin/leaves$qs'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load leave requests');
    }
  }

  // Approve or Reject a leave request
  static Future<void> updateLeaveStatus(int id, String status, {String? rejectionReason}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/leaves/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status, 'rejectionReason': rejectionReason}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update leave status');
    }
  }

  // Create a brand new employee account
  static Future<void> createUser(Map<String, dynamic> userData, {XFile? image}) async {
    final company = await _getCompany();
    if (company != null) userData['company'] = company;

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/admin/users'));
    userData.forEach((key, value) {
      request.fields[key] = value.toString();
    });
    
    if (image != null) {
      var multipartFile = await http.MultipartFile.fromPath('profilePicture', image.path);
      request.files.add(multipartFile);
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to create user';
      throw Exception(error);
    }
  }

  // Permanently remove a user from the system
  static Future<void> deleteUser(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/users/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete user');
    }
  }

  // Temporarily disable an employee's access
  static Future<void> toggleEmployeeActive(int id, bool isActive) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/users/$id/active'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'isActive': isActive ? 1 : 0}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to update status';
      throw Exception(error);
    }
  }

  // --- Shift Management ---
  // Shifts define when people work (e.g., Morning Shift: 9 AM to 5 PM)
  static Future<List<dynamic>> getShifts() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await http.get(Uri.parse('$baseUrl/admin/shifts$qs'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load shifts');
    }
  }

  static Future<void> createShift(Map<String, dynamic> shiftData) async {
    final company = await _getCompany();
    if (company != null) shiftData['company'] = company;
    final response = await http.post(
      Uri.parse('$baseUrl/admin/shifts'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(shiftData),
    );
     if (response.statusCode != 200) {
      throw Exception('Failed to create shift: ${response.body}');
    }
  }

  static Future<void> updateShift(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/shifts/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to update shift');
  }

  static Future<void> deleteShift(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/shifts/$id'));
    if (response.statusCode != 200) throw Exception('Failed to delete shift');
  }

  // --- Company Settings ---
  // Settings like "Company Name", "Country", or "Currency"
  static Future<Map<String, dynamic>> getSettings({String? company}) async {
    final effectiveCompany = company ?? await _getCompany();
    String qs = effectiveCompany != null ? '?company=${Uri.encodeComponent(effectiveCompany)}' : '';
    final response = await http.get(Uri.parse('$baseUrl/settings$qs'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load settings');
    }
  }

  static Future<void> updateSettings(Map<String, dynamic> settingsData) async {
    final company = await _getCompany();
    if (company != null) settingsData['companyName'] = company;
    final response = await http.post(
      Uri.parse('$baseUrl/admin/settings'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(settingsData),
    );
     if (response.statusCode != 200) {
      throw Exception('Failed to update settings');
    }
  }

  // --- Notifications ---
  // Bell icons, unread alerts, etc.
  static Future<List<dynamic>> getNotifications(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/notifications/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  static Future<void> markNotificationRead(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/notifications/$id/read'));
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  // --- Holidays ---
  // Public holidays like "New Year's Day"
  static Future<List<dynamic>> getHolidays() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await http.get(Uri.parse('$baseUrl/admin/holidays$qs'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load holidays');
  }

  static Future<void> addHoliday(String name, String date, {String type = 'Public', String duration = 'Full Day'}) async {
    final company = await _getCompany();
    final data = {
      'name': name, 'date': date, 'type': type, 'duration': duration,
    };
    if (company != null) data['company'] = company;
    
    final response = await http.post(
      Uri.parse('$baseUrl/admin/holidays'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to add holiday');
  }

  static Future<void> deleteHoliday(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/holidays/$id'));
    if (response.statusCode != 200) throw Exception('Failed to delete holiday');
  }

  // --- Reports (The CSV/PDF stuff) ---
  static Future<List<dynamic>> getAttendanceReport({DateTime? startDate, DateTime? endDate}) async {
    String query = '';
    final company = await _getCompany();
    if (startDate != null && endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);
      query = '?startDate=$startStr&endDate=$endStr';
      if (company != null) query += '&company=${Uri.encodeComponent(company)}';
    } else if (company != null) {
      query = '?company=${Uri.encodeComponent(company)}';
    }
    
    final response = await http.get(Uri.parse('$baseUrl/admin/reports/attendance$query'));
     if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load report');
    }
  }

  static Future<List<dynamic>> getPayrollReport({DateTime? startDate, DateTime? endDate}) async {
    final company = await _getCompany();
    final params = <String, String>{};
    if (startDate != null) params['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
    if (endDate != null) params['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
    if (company != null) params['company'] = company;
    
    final uri = Uri.parse('$baseUrl/admin/reports/payroll').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load payroll report');
    }
  }

  static Future<List<dynamic>> getOvertimeReport({DateTime? startDate, DateTime? endDate}) async {
    final params = <String, String>{};
    final company = await _getCompany();
    if (startDate != null) params['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
    if (endDate != null) params['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
    if (company != null) params['company'] = company;

    final uri = Uri.parse('$baseUrl/admin/reports/overtime').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load overtime report');
    }
  }

  static Future<List<dynamic>> getSalaryHoursReport({DateTime? startDate, DateTime? endDate}) async {
    final params = <String, String>{};
    final company = await _getCompany();
    if (startDate != null) params['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
    if (endDate != null) params['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
    if (company != null) params['company'] = company;

    final uri = Uri.parse('$baseUrl/admin/reports/salary-hours').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load salary hours report');
    }
  }

  // --- Leave Management (Admin) ---
  
  static Future<List<dynamic>> getLeavePolicies() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await http.get(Uri.parse('$baseUrl/admin/leave-policies$qs'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load leave policies');
    }
  }

  static Future<void> saveLeavePolicy(Map<String, dynamic> policyData) async {
    final company = await _getCompany();
    if (company != null) policyData['company'] = company;
    final response = await http.post(
      Uri.parse('$baseUrl/admin/leave-policies'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(policyData),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save leave policy');
    }
  }

  static Future<void> adjustLeaveBalance(int userId, String leaveType, int totalDays) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/leave-balance'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'leaveType': leaveType,
        'totalDays': totalDays,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to adjust leave balance');
    }
  }



  static Future<Map<String, dynamic>> updateBranding({XFile? logo, String? themeColor}) async {
    final company = await _getCompany();
    if (company == null) throw Exception('Company not found');

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/admin/branding'));
    request.fields['company'] = company;
    if (themeColor != null) request.fields['themeColor'] = themeColor;
    
    if (logo != null) {
      request.files.add(await http.MultipartFile.fromPath('logo', logo.path));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update branding: ${response.body}');
    }
  }

  // --- Payslips ---
  // Creating and viewing salary slips
  static Future<void> createPayslip(Map<String, dynamic> data) async {
    final company = await _getCompany();
    if (company != null) data['company'] = company;
    
    final response = await http.post(
      Uri.parse('$baseUrl/admin/payslips'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to create payslip');
  }

  static Future<List<dynamic>> getAdminPayslips() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await http.get(Uri.parse('$baseUrl/admin/payslips$qs'));
    
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load payslips');
  }

  static Future<List<dynamic>> getUserPayslips(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/payslips/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load your payslips');
  }

  static Future<void> deletePayslip(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/payslips/$id'));
    if (response.statusCode != 200) throw Exception('Failed to delete payslip');
  }
}
