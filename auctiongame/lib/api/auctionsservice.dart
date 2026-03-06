import 'dart:convert';
import 'package:auctiongame/constants.dart';
import 'package:http/http.dart' as http;

class AuctionService {
  static Future<List<Map<String, dynamic>>> fetchAuctions() async {
    print('here in fetchAuctions');
    try {
      final response = await http.get(
        Uri.parse('$serverurl/auction'),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('data==? $data');
        // Assuming your API returns a list of auctions
        return List<Map<String, dynamic>>.from(data['data'] ?? data);
      } else {
        throw Exception('Failed to load auctions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching auctions: $e');
      throw Exception('Failed to fetch auctions: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchAuctionById(int auctionId) async {
    try {
      final response = await http.get(
        Uri.parse('$serverurl/auction/$auctionId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load auction: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching auction: $e');
      throw Exception('Failed to fetch auction: $e');
    }
  }

  static Future<dynamic> createAuction({data}) async {
    print(data);
    try {
      final response = await http.post(
        Uri.parse('$serverurl/auction'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      print("Raw response: ${response.body}");

      if (response.statusCode == 201) {
        final body = response.body;

        // If it's JSON, decode, otherwise just return the string
        try {
          return json.decode(body);
        } catch (e) {
          return body; // fallback to raw string
        }
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching auction: $e');
      throw Exception('Failed to fetch auction: $e');
    }
  }

  static Future<dynamic> getGroupsByCategory(String category) async {
    return await http.get(
      Uri.parse('${serverurl}/player/groups-admin-isActive?category=$category'),
    );
  }

  static Future<dynamic> getPlayersByCategory(String category) async {
    return await http.get(Uri.parse('${serverurl}/player/category/$category'));
  }

  static Future<dynamic> getPlayersByGroup(String groupName) async {
    return await http.get(Uri.parse('${serverurl}/player/group/$groupName'));
  }
}
