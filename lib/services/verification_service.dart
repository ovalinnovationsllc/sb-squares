import 'dart:convert';
import 'package:http/http.dart' as http;

class VerificationService {
  static const String _baseUrl = 'https://us-central1-sb-squares-100ee.cloudfunctions.net';

  /// Sends a verification code to the user's email
  Future<({bool success, String message})> sendVerificationCode({
    required String email,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sendVerificationCode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': {
            'email': email,
            'userId': userId,
          }
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['result'] != null) {
        return (
          success: data['result']['success'] as bool,
          message: data['result']['message'] as String,
        );
      } else {
        final error = (data['error']?['message'] ?? 'Failed to send verification code').toString();
        return (success: false, message: error);
      }
    } catch (e) {
      print('Error sending verification code: $e');
      return (
        success: false,
        message: 'Failed to send verification code. Please try again.',
      );
    }
  }

  /// Verifies the code entered by the user
  Future<({bool success, String message})> verifyCode({
    required String userId,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verifyCode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': {
            'userId': userId,
            'code': code,
          }
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['result'] != null) {
        return (
          success: data['result']['success'] as bool,
          message: data['result']['message'] as String,
        );
      } else {
        final error = (data['error']?['message'] ?? 'Invalid verification code').toString();
        return (success: false, message: error);
      }
    } catch (e) {
      print('Error verifying code: $e');
      return (
        success: false,
        message: 'Failed to verify code. Please try again.',
      );
    }
  }
}
