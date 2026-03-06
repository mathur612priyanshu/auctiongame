import 'dart:convert';
import 'dart:io';
import 'package:auctiongame/constants.dart';
import 'package:http/http.dart' as http;
import 'package:auctiongame/helpers/tokenmanager.dart';

class AuthService {
  // Send OTP to the provided phone number
  static Future<bool> sendOtp(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$serverurl/auth/send_verification_code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }

  // Verify the OTP entered by the user
  static Future<bool> verifyOtp(String otp, String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$serverurl/auth/otpverify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'otp': otp, 'phoneNumber': phoneNumber}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Store the auth token using your existing TokenManager
        if (data['token'] != null) {
          await TokenManager.setToken(data['token']);
        }

        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to verify OTP');
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  // Update user profile information
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String? dob,
    File? image,
  }) async {
    final token = await TokenManager.getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    try {
      var uri = Uri.parse('$serverurl/profile-update');

      var request =
          http.MultipartRequest('PUT', uri)
            ..headers['Authorization'] = 'Bearer $token'
            ..fields['name'] = name
            ..fields['email'] = email;

      if (dob != null) {
        request.fields['dob'] = dob;
      }

      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file', // must match the backend field name
            image.path,
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'user': data['user']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      print('Error updating profile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get user details
  static Future<Map<String, dynamic>?> getUserDetails() async {
    final token = await TokenManager.getToken();
    if (token == null) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$serverurl/auth/userdetail'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['user'];
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get user details');
      }
    } catch (e) {
      print('Error getting user details: $e');
      return null;
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await TokenManager.getToken();
    if (token == null) {
      return false;
    }

    // Verify token validity by fetching user details
    final userDetails = await getUserDetails();
    return userDetails != null;
  }

  // Logout user
  static Future<void> logout() async {
    await TokenManager.removeToken();
  }
}
