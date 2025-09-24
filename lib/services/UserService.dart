// services/UserService.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _baseUrl = 'http://10.0.0.158:8000/api/';

  
    // Add to UserService.dart
  static Future<Map<String, dynamic>> getUserProfileByUsername(String username) async {
    final String url = 'http://10.0.0.158:8000/api/profile/$username/';
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');


    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token}',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load profile');
    }
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    final response = await http.get(
      Uri.parse('${_baseUrl}profile/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // 'X-Client-Version': '1.0.0',
        // 'X-Client-Platform': 'flutter-ios',

        'Authorization': 'Bearer $token'
        },
    );
    
    if (response.statusCode == 200) {
      print("Request successful");
      final responseBody = json.decode(response.body);

      // Check if the response is a list and get the first item
      if (responseBody is List && responseBody.isNotEmpty) {
        print("Response is a list with length: ${responseBody.length}");
        return responseBody[0]; // Return the first object in the list
      } else if (responseBody is Map<String, dynamic>) {
        print("Response is a single object");
        return responseBody; // Handle the case where the API returns a single object
      }
    
      return json.decode(response.body);
    } else {
      final profile = prefs.getString('profile');
      if (profile != null) {
        return json.decode(profile);
      }
      throw Exception('Failed to load profile1');
      
    }
  }
  
  static Future<Map<String, int>> getCoinBalances() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    final response = await http.get(
      Uri.parse('${_baseUrl}coin-balances/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // 'X-Client-Version': '1.0.0',
        // 'X-Client-Platform': 'flutter-ios',

        'Authorization': 'Bearer $token'
        },
    );
    
    if (response.statusCode == 200) {
      
      return Map<String, int>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load coin balances');
    }
  }
  
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print('Sending profile update: ${json.encode(data)}');
    
    
    if (data['image'] is! File) {
      data.remove('image');
    }

    // Reformat date just in case
    if (data['date_of_birth'] != null) {
      final dob = DateTime.tryParse(data['date_of_birth']);
      if (dob != null) {
        data['date_of_birth'] = "${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}";
      } else {
        data.remove('date_of_birth'); // or show error to user
      }
    }
    final response = await http.put(
      Uri.parse('${_baseUrl}profile/update/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Client-Version': '1.0.0',
        'X-Client-Platform': 'flutter-ios',

        'Authorization': 'Token $token',
      },
      body: json.encode(data),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Update failed');
    }
  }
}