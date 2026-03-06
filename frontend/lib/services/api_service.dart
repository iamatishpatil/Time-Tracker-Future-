// --- 1. The API Bridge (Service Layer) ---
// This file is like a "postman". Its only job is to take data from our 
// Flutter screens and "deliver" it to the server, then bring back the answer.

import 'dart:async'; // For TimeoutException
import 'dart:convert'; // Converts text/json into stuff Dart understand
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http; // The tool we use to talk to the internet
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Local storage (like a tiny vault)
import 'package:intl/intl.dart';

class ApiService {
  // --- The Server Address ---
  // Every server has an address (IP). We use this to tell Flutter where to send data.
  static const String baseUrl = 'http://10.157.170.65:3000/api';

  // --- Performance: Default HTTP timeout ---
  static const Duration _defaultTimeout = Duration(seconds: 10);

  // --- Internal Security: JWT Injector ---
  static Future<Map<String, String>> _getHeaders(Map<String, String>? customHeaders) async {
    final headers = await _getAuthHeaders();
    if (customHeaders != null) headers.addAll(customHeaders);
    if (!headers.containsKey('Content-Type')) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  // --- Internal Security: JWT Injector for Multipart ---
  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Fast GET with timeout + JWT
  static Future<http.Response> _get(String url, {Map<String, String>? headers}) async {
    final finalHeaders = await _getHeaders(headers);
    return http.get(Uri.parse(url), headers: finalHeaders).timeout(_defaultTimeout);
  }

  // Fast POST with timeout + JWT
  static Future<http.Response> _post(String url, {Map<String, String>? headers, Object? body}) async {
    final finalHeaders = await _getHeaders(headers);
    return http.post(Uri.parse(url), headers: finalHeaders, body: body).timeout(_defaultTimeout);
  }

  // Fast PUT with timeout + JWT
  static Future<http.Response> _put(String url, {Map<String, String>? headers, Object? body}) async {
    final finalHeaders = await _getHeaders(headers);
    return http.put(Uri.parse(url), headers: finalHeaders, body: body).timeout(_defaultTimeout);
  }

  // Fast PATCH with timeout + JWT
  static Future<http.Response> _patch(String url, {Map<String, String>? headers, Object? body}) async {
    final finalHeaders = await _getHeaders(headers);
    return http.patch(Uri.parse(url), headers: finalHeaders, body: body).timeout(_defaultTimeout);
  }

  // Fast DELETE with timeout + JWT
  static Future<http.Response> _delete(String url, {Map<String, String>? headers, Object? body}) async {
    final finalHeaders = await _getHeaders(headers);
    return http.delete(Uri.parse(url), headers: finalHeaders, body: body).timeout(_defaultTimeout);
  }

  // Helper to get full URLs for images stored on the server
  static String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return baseUrl.replaceAll('/api', '') + path;
  }

  // --- Performance: Cached company lookup ---
  static String? _cachedCompany;

  // A private helper to find out which company the current user belongs to
  // Caches the result to avoid repeated SharedPreferences reads
  static Future<String?> _getCompany() async {
    if (_cachedCompany != null) return _cachedCompany;
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      try {
        final user = json.decode(userStr);
        _cachedCompany = user['company'];
        return _cachedCompany;
      } catch (_) {}
    }
    return null;
  }

  // Call this on logout to clear the cache
  static Future<void> _clearCache() async {
    _cachedCompany = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user');
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
        final data = json.decode(response.body); // Server says YES!
        if (data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', data['token']);
          await prefs.setString('user', json.encode(data['user']));
        }
        return data; 
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
  static Future<Map<String, dynamic>> login(String mobileNumber, String password, {String? biometricToken}) async {
    try {
      final body = {'mobileNumber': mobileNumber, 'password': password};
      if (biometricToken != null) {
        body['biometricToken'] = biometricToken;
      }
      
      // http.post sends a standard "package" of data to the server
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // --- IMPORTANT: Session Persistence ---
        // We save the user's data in the phone's memory (SharedPreferences)
        // so the app remembers they are logged in even if they close it.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(data['user']));
        if (data['token'] != null) {
          await prefs.setString('jwt_token', data['token']);
        }
        
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

  // --- Biometric Login ---
  static Future<Map<String, dynamic>> loginWithBiometric(String biometricToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/biometric'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'biometricToken': biometricToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(data['user']));
        if (data['token'] != null) {
          await prefs.setString('jwt_token', data['token']);
        }
        return data;
      } else {
        String errorMessage = 'Biometric login failed';
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

    // Add Auth Headers
    request.headers.addAll(await _getAuthHeaders());

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

    // Add Auth Headers
    request.headers.addAll(await _getAuthHeaders());

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

  // --- Geofencing: Report Periodic Location ---
  static Future<void> reportLocation(int userId, double lat, double long) async {
    try {
      await _post(
        '$baseUrl/attendance/geofence-alert',
        body: json.encode({
          'userId': userId,
          'lat': lat,
          'long': long,
        }),
      );
    } catch (e) {
      debugPrint('reportLocation error: $e');
    }
  }

  static Future<void> checkOut(int userId, {double? lat, double? long, String? address, XFile? photo}) async {
    var uri = Uri.parse('$baseUrl/checkout');
    var request = http.MultipartRequest('POST', uri);
    
    request.fields['userId'] = userId.toString();
    if (lat != null) request.fields['lat'] = lat.toString();
    if (long != null) request.fields['long'] = long.toString();
    if (address != null) request.fields['address'] = address;

    // Add Auth Headers
    request.headers.addAll(await _getAuthHeaders());

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
  static Future<List<dynamic>> getAttendance(int userId, {DateTime? startDate, DateTime? endDate}) async {
    String url = '$baseUrl/attendance/$userId';
    if (startDate != null && endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);
      url += '?startDate=$startStr&endDate=$endStr';
    }
    final response = await _get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load attendance');
    }
  }

  // Checks if the user is currently "on the clock"
  static Future<Map<String, dynamic>> getCheckInStatus(int userId) async {
    final response = await _get('$baseUrl/attendance/status/$userId');
    if (response.statusCode == 200) {
      return json.decode(response.body); // Returns { isCheckedIn: true/false }
    } else {
      return {'isCheckedIn': false};
    }
  }

  // Get user-specific dashboard stats via server-side computation.
  // ANR Fix: No longer downloads all records - server does the SQL aggregation.
  static Future<Map<String, dynamic>> getDashboardStats(int userId) async {
    try {
      final response = await _get('$baseUrl/attendance/stats/$userId');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('getDashboardStats error: $e');
    }
    return {'todayHours': '0.0', 'monthHours': '0.0', 'attendanceRate': 0};
  }

  
  // Clear the phone's memory to log the user out
  static Future<void> logout() async {
    await _clearCache(); // Clears all local storage (user & jwt_token)
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
    final response = await _post(
      '$baseUrl/change-password',
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
    final response = await _post(
      '$baseUrl/leaves/apply',
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to apply for leave: ${response.body}');
    }
  }

  // Get a list of all leaves the CURRENT user has applied for
  static Future<List<dynamic>> getLeaveHistory(int userId) async {
    final response = await _get('$baseUrl/leaves/$userId');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load leave history');
    }
  }

  // Cancel a leave request that hasn't started yet
  static Future<void> cancelLeave(int leaveId, int userId) async {
    final response = await _put(
      '$baseUrl/leaves/$leaveId/cancel',
      body: json.encode({'userId': userId}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to cancel leave';
      throw Exception(error);
    }
  }

  // Find out how many leave days are LEFT for the user (e.g., 10 Sick leaves remaining)
  static Future<Map<String, dynamic>> getLeaveBalance(int userId) async {
    try {
      final response = await _get('$baseUrl/leaves/balance/$userId');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('[ApiService] getLeaveBalance error: $e');
    }
    // Return safe defaults so screens don't crash
    return {'total': 0, 'used': 0, 'remaining': 0};
  }

  // Get a list of the types of leave allowed by the company
  static Future<List<String>> getLeaveTypes() async {
    final company = await _getCompany();
    if (company == null) {
      print('[ApiService] WARNING: getLeaveTypes called without company context');
      return ['Sick Leave', 'Casual Leave', 'Earned Leave'];
    }
    String qs = '?company=${Uri.encodeComponent(company)}';
    final response = await _get('$baseUrl/leaves/types$qs');
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((e) => e.toString()).toList();
    } else {
      // Default list if the server request fails
      return ['Sick Leave', 'Casual Leave', 'Earned Leave'];
    }
  }

  // --- Performance: Parsing JSON in a separate Isolate ---
  // Large JSON payloads from the server block the main UI thread during parsing. 
  // We offset this to a separate CPU thread to ensure the app never stutters.
  static Map<String, dynamic> _parseJsonMap(String responseBody) {
    return json.decode(responseBody) as Map<String, dynamic>;
  }

  static List<dynamic> _parseJsonList(String responseBody) {
    return json.decode(responseBody) as List<dynamic>;
  }

  // ============ ADMIN METHODS ============

  // --- Admin: Metrics & Reports ---
  // Get counts for the dashboard (e.g., Total Employees: 50, Present: 40)
  static Future<Map<String, dynamic>> getAdminStats() async {
    final company = await _getCompany();
    if (company == null) throw Exception('Company context missing. Please login again.');
    String qs = '?company=${Uri.encodeComponent(company)}';
    final response = await _get('$baseUrl/admin/stats$qs');
    if (response.statusCode == 200) {
      return await compute(_parseJsonMap, response.body);
    } else {
      throw Exception('Failed to load admin stats');
    }
  }

  // Get a list of ALL employees in the company
  static Future<List<dynamic>> getAllUsers() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await _get('$baseUrl/admin/users$qs');
    if (response.statusCode == 200) {
      return await compute(_parseJsonList, response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  // Find employees who didn't show up today
  static Future<List<dynamic>> getAbsentEmployees() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await _get('$baseUrl/admin/absences$qs');
    if (response.statusCode == 200) {
      return await compute(_parseJsonList, response.body);
    } else {
      throw Exception('Failed to load absent employees');
    }
  }

  // --- Admin: Advanced Attendance & User Management ---
  // Get all records, but with options to filter by date, user, or department
  static Future<List<dynamic>> getAllAttendance({int? userId, DateTime? startDate, DateTime? endDate, String? department, int? limit}) async {
    final params = <String, String>{};
    if (userId != null) params['userId'] = userId.toString();
    if (startDate != null) params['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
    if (endDate != null) params['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
    if (department != null) params['department'] = department;
    if (limit != null) params['limit'] = limit.toString();
    
    final company = await _getCompany();
    if (company != null) params['company'] = company;

    final uri = Uri.parse('$baseUrl/admin/attendance').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await _get(uri.toString());
    if (response.statusCode == 200) {
      return await compute(_parseJsonList, response.body);
    } else {
      throw Exception('Failed to load attendance records');
    }
  }

  // Admin can change an employee's check-in/out time if they made a mistake
  static Future<void> updateAttendance(int id, Map<String, dynamic> data) async {
    final company = await _getCompany();
    data['company'] = company;
    final response = await _put(
      '$baseUrl/admin/attendance/$id',
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to update attendance';
      throw Exception(error);
    }
  }

  // Admin can manually add an attendance entry for someone
  static Future<void> createManualAttendance(Map<String, dynamic> data) async {
    final company = await _getCompany();
    data['company'] = company; // Although the backend might use userId to find company, passing it explicitly is safer
    final response = await _post(
      '$baseUrl/admin/attendance',
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
    final response = await _get('$baseUrl/admin/leaves$qs');
    if (response.statusCode == 200) {
      return await compute(_parseJsonList, response.body);
    } else {
      throw Exception('Failed to load leave requests');
    }
  }

  // Approve or Reject a leave request
  static Future<void> updateLeaveStatus(int id, String status, {String? rejectionReason}) async {
    final company = await _getCompany();
    final response = await _put(
      '$baseUrl/admin/leaves/$id',
      body: json.encode({
        'status': status, 
        'rejectionReason': rejectionReason,
        'company': company,
      }),
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

    // Add Auth Headers
    request.headers.addAll(await _getAuthHeaders());
    
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

  static Future<void> toggleUserApproval(int id, bool isApproved, {String? reason}) async {
    final company = await _getCompany();
    final response = await _patch(
      '$baseUrl/admin/users/$id/approve',
      body: json.encode({
        'isApproved': isApproved ? 1 : 0,
        'company': company,
        'rejectionReason': reason,
      }),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to update approval status';
      throw Exception(error);
    }
  }

  static Future<void> toggleEmployeeActive(int id, bool isActive) async {
    final company = await _getCompany();
    final response = await _patch(
      '$baseUrl/admin/users/$id/active',
      body: json.encode({
        'isActive': isActive ? 1 : 0,
        'company': company,
      }),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to update status';
      throw Exception(error);
    }
  }

  static Future<void> deleteUser(int id) async {
    final company = await _getCompany();
    final response = await _delete(
      '$baseUrl/admin/users/$id',
      body: json.encode({'company': company}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete user');
    }
  }

  // --- Shift Management ---
  // Shifts define when people work (e.g., Morning Shift: 9 AM to 5 PM)
  static Future<List<dynamic>> getShifts() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await _get('$baseUrl/admin/shifts$qs');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load shifts');
    }
  }

  static Future<void> createShift(Map<String, dynamic> shiftData) async {
    final company = await _getCompany();
    if (company != null) shiftData['company'] = company;
    final response = await _post(
      '$baseUrl/admin/shifts',
      body: json.encode(shiftData),
    );
     if (response.statusCode != 200) {
      throw Exception('Failed to create shift: ${response.body}');
    }
  }

  static Future<void> updateShift(int id, Map<String, dynamic> data) async {
    final company = await _getCompany();
    data['company'] = company;
    final response = await _put(
      '$baseUrl/admin/shifts/$id',
      body: json.encode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to update shift');
  }

  static Future<void> deleteShift(int id) async {
    final company = await _getCompany();
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/shifts/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'company': company}),
    );
    if (response.statusCode != 200) throw Exception('Failed to delete shift');
  }

  // --- Company Settings ---
  // Settings like "Company Name", "Country", or "Currency"
  static Future<Map<String, dynamic>> getSettings({String? company}) async {
    try {
      final effectiveCompany = company ?? await _getCompany();
      String qs = effectiveCompany != null ? '?company=${Uri.encodeComponent(effectiveCompany)}' : '';
      final response = await _get('$baseUrl/settings$qs')
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      debugPrint('[ApiService] getSettings returned ${response.statusCode}');
    } catch (e) {
      debugPrint('[ApiService] getSettings error: $e');
    }
    // Return safe empty map so screens don't crash
    return {};
  }

  static Future<void> updateSettings(Map<String, dynamic> settingsData) async {
    final companyId = await _getCompany();
    if (companyId != null) settingsData['company'] = companyId;
    final response = await _post(
      '$baseUrl/admin/settings',
      body: json.encode(settingsData),
    );
     if (response.statusCode != 200) {
      throw Exception('Failed to update settings');
    }
  }

  // --- Notifications ---
  // Bell icons, unread alerts, etc.
  static Future<List<dynamic>> getNotifications(int userId) async {
    final response = await _get('$baseUrl/notifications/$userId');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  static Future<void> markNotificationRead(int id) async {
    final response = await _put('$baseUrl/notifications/$id/read');
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  // --- Holidays ---
  // Public holidays like "New Year's Day"
  // --- Performance: Request Deduplication ---
  static Future<List<dynamic>>? _holidaysFuture;

  static Future<List<dynamic>> getHolidays() async {
    // If a request is already in-flight, reuse it
    if (_holidaysFuture != null) return _holidaysFuture!;

    _holidaysFuture = () async {
      try {
        final company = await _getCompany();
        if (company == null) {
          debugPrint('[ApiService] WARNING: getHolidays called without company context');
          _holidaysFuture = null;
          return <dynamic>[];
        }
        String qs = '?company=${Uri.encodeComponent(company)}';
        final response = await _get('$baseUrl/admin/holidays$qs');
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List<dynamic>;
          // Clear cache after 5 seconds so future navigations get fresh data
          Future.delayed(const Duration(seconds: 5), () => _holidaysFuture = null);
          return data;
        }
        // Non-200: clear cache immediately and return empty
        _holidaysFuture = null;
        debugPrint('[ApiService] getHolidays returned ${response.statusCode}');
        return <dynamic>[];
      } catch (err) {
        // On network error: clear cache so next call retries
        _holidaysFuture = null;
        debugPrint('[ApiService] getHolidays error: $err');
        return <dynamic>[];
      }
    }();

    return _holidaysFuture!;
  }

  static Future<void> addHoliday(String name, String date, {String type = 'Public', String duration = 'Full Day'}) async {
    final company = await _getCompany();
    final data = {
      'name': name, 'date': date, 'type': type, 'duration': duration,
    };
    if (company != null) data['company'] = company;
    
    final response = await _post(
      '$baseUrl/admin/holidays',
      body: json.encode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to add holiday');
  }

  static Future<void> deleteHoliday(int id) async {
    final company = await _getCompany();
    final response = await _delete(
      '$baseUrl/admin/holidays/$id',
      body: json.encode({'company': company}),
    );
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
    
    final response = await _get('$baseUrl/admin/reports/attendance$query');
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
    final response = await _get(uri.toString());
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
    final response = await _get(uri.toString());
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
    final response = await _get(uri.toString());
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
    final response = await _get('$baseUrl/admin/leave-policies$qs');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load leave policies');
    }
  }

  static Future<void> saveLeavePolicy(Map<String, dynamic> policyData) async {
    final company = await _getCompany();
    if (company != null) policyData['company'] = company;
    final response = await _post(
      '$baseUrl/admin/leave-policies',
      body: json.encode(policyData),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save leave policy');
    }
  }

  static Future<void> adjustLeaveBalance(int userId, String leaveType, int totalDays) async {
    final company = await _getCompany();
    final response = await _put(
      '$baseUrl/admin/leave-balance',
      body: json.encode({
        'userId': userId,
        'leaveType': leaveType,
        'totalDays': totalDays,
        'company': company,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to adjust leave balance');
    }
  }



  static Future<Map<String, dynamic>> updateBranding({XFile? logo, String? themeColor, String? secondaryColor, String? accentColor}) async {
    final company = await _getCompany();
    if (company == null) throw Exception('Company not found');

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/admin/branding'));
    
    request.headers.addAll(await _getAuthHeaders());

    request.fields['company'] = company;
    if (themeColor != null) request.fields['themeColor'] = themeColor;
    if (secondaryColor != null) request.fields['secondaryColor'] = secondaryColor;
    if (accentColor != null) request.fields['accentColor'] = accentColor;
    
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
    
    final response = await _post(
      '$baseUrl/admin/payslips',
      body: json.encode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to create payslip');
  }

  static Future<List<dynamic>> getAdminPayslips() async {
    final company = await _getCompany();
    String qs = company != null ? '?company=${Uri.encodeComponent(company)}' : '';
    final response = await _get('$baseUrl/admin/payslips$qs');
    
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load payslips');
  }

  static Future<List<dynamic>> getUserPayslips(int userId) async {
    try {
      final response = await _get('$baseUrl/payslips/$userId');
      if (response.statusCode == 200) return json.decode(response.body);
      debugPrint('[ApiService] getUserPayslips returned ${response.statusCode}');
    } catch (e) {
      debugPrint('[ApiService] getUserPayslips error: $e');
    }
    return [];
  }

  static Future<void> deletePayslip(int id) async {
    final company = await _getCompany();
    final response = await _delete(
      '$baseUrl/admin/payslips/$id',
      body: json.encode({'company': company}),
    );
    if (response.statusCode != 200) throw Exception('Failed to delete payslip');
  }
}
