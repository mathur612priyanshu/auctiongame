import 'dart:convert';
import 'package:auctiongame/constants.dart';
import 'package:auctiongame/helpers/tokenmanager.dart';
import 'package:http/http.dart' as http;

class DutyService {
  Future<List<Map<String, dynamic>>> fetchDuties({
    required int page,
    int limit = 10,
    String sortBy = "created_at",
    String order = "desc",
    String? search = "",
  }) async {
    String? token = await TokenManager.getToken();

    try {
      final response = await http.get(
        Uri.parse(
          "$serverurl/duties/get_duties?page=$page&limit=$limit&sort_by=$sortBy&order=$order${search!.isNotEmpty ? '&search=$search' : ''}",
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data["duties"]);
      } else {
        throw Exception("Failed to load duties");
      }
    } catch (e) {
      throw Exception("Error fetching duties: $e");
    }
  }

  // Replace with your API URL

  Future<List<Map<String, dynamic>>> fetchBookings() async {
    String? token = await TokenManager.getToken();

    final response = await http.get(
      Uri.parse('$serverurl/duties/my_duties'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // print(data);

      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception("Failed to load bookings");
    }
  }

  Future<void> updateBookingStatus(int bookingId, String newStatus) async {
    String? token = await TokenManager.getToken();
    print(token);
    // Ensure status is always boolean
    bool statusBool;
    if (newStatus == 'Booked') {
      statusBool = true;
    } else if (newStatus == 'Not Booked') {
      statusBool = false;
    } else {
      throw Exception("Invalid status: $newStatus");
    }

    final url = Uri.parse('$serverurl/duties/updateBookingStatus');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "booking_id": bookingId,
        "status": statusBool, // Ensured to be true/false
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to update booking status, ${response.body}");
    }
  }

  Future<void> updateVehicleBookingStatus(
    int bookingId,
    String newStatus,
  ) async {
    String? token = await TokenManager.getToken();
    print(token);
    // Ensure status is always boolean
    bool statusBool;
    if (newStatus == 'Booked') {
      statusBool = true;
    } else if (newStatus == 'Not Booked') {
      statusBool = false;
    } else {
      throw Exception("Invalid status: $newStatus");
    }

    final url = Uri.parse('$serverurl/duties/updateVehicleBookingStatus');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "booking_id": bookingId,
        "status": statusBool, // Ensured to be true/false
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to update booking status, ${response.body}");
    }
  }

  Future<List<Map<String, dynamic>>> fetchVehicles({
    required int page,
    int limit = 3,
    String sortBy = "created_at",
    String order = "desc",
    String? search = "",
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          "$serverurl/duties/get_vehicles?page=$page&limit=$limit&sort_by=$sortBy&order=$order${search!.isNotEmpty ? '&search=$search' : ''}",
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data["vehicles"]);
      } else {
        throw Exception("Failed to load vehicles");
      }
    } catch (e) {
      throw Exception("Error fetching vehicles: $e");
    }
  }

  Future<List<dynamic>> fetchCabData() async {
    String? token = await TokenManager.getToken();

    try {
      // Replace with your actual API endpoint
      final response = await http.get(
        Uri.parse('$serverurl/duties/my_vehicles'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load cab data');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<int> fetchTodayDutiesCount() async {
    try {
      final response = await http.get(
        Uri.parse("$serverurl/duties/total_duties_today"),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['todayDutiesCount'] as int;
      } else {
        throw Exception("Failed to fetch duties count");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<void> deleteDuty(int dutyId) async {
    String? token = await TokenManager.getToken();

    final response = await http.delete(
      Uri.parse('$serverurl/duties/delete_duty/$dutyId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete duty');
    }
  }

  Future<void> deleteCab(int dutyId) async {
    String? token = await TokenManager.getToken();

    final response = await http.delete(
      Uri.parse('$serverurl/duties/delete_cab/$dutyId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete duty');
    }
  }
}
