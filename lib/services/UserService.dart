// services/UserService.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _baseUrl = 'http://10.0.0.158:5000/api/';

  // Video-related API methods
  static Future<Map<String, dynamic>> uploadVideo(File videoFile, {String title = '', String description = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      throw Exception('Please login to upload video');
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${_baseUrl}videos/upload/'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    // Add video file
    request.files.add(await http.MultipartFile.fromPath(
      'video_file',
      videoFile.path,
      filename: 'edited_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
    ));

    // Add form data
    request.fields['title'] = title.isNotEmpty ? title : 'Edited Video ${DateTime.now().toString()}';
    request.fields['description'] = description.isNotEmpty ? description : 'Video edited in BBDSocial app';

    final response = await request.send();
    final responseString = await response.stream.bytesToString();
    
    if (response.statusCode == 201) {
      return json.decode(responseString);
    } else {
      try {
        final errorResponse = json.decode(responseString);
        throw Exception('Upload failed: ${errorResponse['error'] ?? responseString}');
      } catch (e) {
        throw Exception('Upload failed: ${response.statusCode} - $responseString');
      }
    }
  }

  static Future<List<dynamic>> getVideos({int page = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    final response = await http.get(
      Uri.parse('${_baseUrl}videos/?page=$page'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'] ?? [];
    } else {
      throw Exception('Failed to load videos: ${response.statusCode}');
    }
  }

  static Future<void> likeVideo(int videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      throw Exception('Please login to like videos');
    }

    final response = await http.post(
      Uri.parse('${_baseUrl}videos/$videoId/like/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to like video');
    }
  }

  static Future<void> bookmarkVideo(int videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      throw Exception('Please login to bookmark videos');
    }

    final response = await http.post(
      Uri.parse('${_baseUrl}videos/$videoId/bookmark/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to bookmark video');
    }
  }

  static Future<List<dynamic>> getVideoComments(int videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    final response = await http.get(
      Uri.parse('${_baseUrl}videos/$videoId/comments/'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load comments');
    }
  }

  static Future<void> addComment(int videoId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      throw Exception('Please login to comment');
    }

    final response = await http.post(
      Uri.parse('${_baseUrl}videos/$videoId/comments/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'text': text}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add comment');
    }
  }

  // Existing user profile methods
  static Future<Map<String, dynamic>> getUserProfileByUsername(String username) async {
    final String url = 'http://10.0.0.158:5000/api/profile/$username/';
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
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
        'Authorization': 'Bearer $token'
      },
    );
    
    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);

      if (responseBody is List && responseBody.isNotEmpty) {
        return responseBody[0];
      } else if (responseBody is Map<String, dynamic>) {
        return responseBody;
      }
    
      return json.decode(response.body);
    } else {
      final profile = prefs.getString('profile');
      if (profile != null) {
        return json.decode(profile);
      }
      throw Exception('Failed to load profile');
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
    
    if (data['image'] is! File) {
      data.remove('image');
    }

    if (data['date_of_birth'] != null) {
      final dob = DateTime.tryParse(data['date_of_birth']);
      if (dob != null) {
        data['date_of_birth'] = "${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}";
      } else {
        data.remove('date_of_birth');
      }
    }
    
    final response = await http.put(
      Uri.parse('${_baseUrl}profile/update/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Token $token',
      },
      body: json.encode(data),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Update failed');
    }
  }
}