import 'dart:convert';
import 'package:auctiongame/constants.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class UserAuctionService {
  // Get auctions that user has participated in
  static Future<List<Map<String, dynamic>>> getUserParticipatedAuctions(
    String userId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$serverurl/auction/user/$userId/participated'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load user auctions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user auctions: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get user's team for a specific auction
  static Future<Map<String, dynamic>> getUserTeam(
    String auctionId,
    String userId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$serverurl/auction/$auctionId/user/$userId/team'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data ?? {};
      } else {
        throw Exception('Failed to load user team: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user team: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<List<dynamic>> getAuctionParticipantsWithPlayers(
    String auctionId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$serverurl/auction/$auctionId/participants-with-players'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)['data'];
      } else {
        throw Exception('Failed to load auction participants with players');
      }
    } catch (e) {
      print('Error in getAuctionParticipantsWithPlayers: $e');
      rethrow;
    }
  }

  // Get user's budget for a specific auction
  static Future<Map<String, dynamic>> getUserBudget(
    String auctionId,
    String userId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$serverurl/auction/$auctionId/user/$userId/budget'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load user budget: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user budget: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get all teams for a specific auction
  static Future<List<Map<String, dynamic>>> getAllAuctionTeams(
    String auctionId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$serverurl/auction/$auctionId/teams'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load auction teams: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching auction teams: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getUserEnrichedAuctions(
    String userId,
  ) async {
    final response = await http.get(
      Uri.parse('$serverurl/auction/user-auctions/enriched/$userId'),
    );
    print(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch enriched auctions');
    }
  }
}
