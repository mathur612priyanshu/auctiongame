import 'dart:convert';
import 'package:auctiongame/constants.dart';
import 'package:http/http.dart' as http;

class LeaderboardService {
  // Get leaderboard for specific auction
  static Future<List<Map<String, dynamic>>> getAuctionLeaderboard(
    String auctionId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$serverurl/leaderboard/auction/$auctionId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching leaderboard: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get all leaderboards
  static Future<List<Map<String, dynamic>>> getAllLeaderboards() async {
    try {
      final response = await http.get(
        Uri.parse('$serverurl/leaderboard'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception(
          'Failed to load all leaderboards: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching all leaderboards: $e');
      throw Exception('Network error: $e');
    }
  }
}
