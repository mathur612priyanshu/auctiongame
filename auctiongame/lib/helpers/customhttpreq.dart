import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CustomHttpClient {
  static final _client = http.Client();
  static const _storage = FlutterSecureStorage();

  static Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    bool requireAuth = true,
  }) async {
    Map<String, String> finalHeaders = {'Content-Type': 'application/json'};

    // Add Authorization header only if requireAuth is true
    if (requireAuth) {
      final token = await _storage.read(key: 'token');
      if (token != null) {
        finalHeaders['Authorization'] = 'Bearer $token';
      }
    }

    // Merge with user-provided headers
    finalHeaders.addAll(headers ?? {});

    var response = await _client.post(
      Uri.parse(url),
      headers: finalHeaders,
      body: jsonEncode(body),
    );

    // Handle token expiration
    if (requireAuth && response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        final newToken = await _storage.read(key: 'token');
        if (newToken != null) {
          finalHeaders['Authorization'] = 'Bearer $newToken';
        }

        response = await _client.post(
          Uri.parse(url),
          headers: finalHeaders,
          body: jsonEncode(body),
        );
      }
    }

    return response;
  }

  static Future<bool> _refreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;

    final res = await _client.post(
      Uri.parse('https://yourapi.com/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await _storage.write(key: 'token', value: data['accessToken']);
      return true;
    }

    return false;
  }
}
