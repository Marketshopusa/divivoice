import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/song.dart';
import '../models/cover.dart';
import '../models/room.dart';

class ApiService {
  static String get baseUrl => kIsWeb ? 'http://localhost:8005' : 'http://10.0.2.2:8005';
  
  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  static bool get isAuthenticated => _token != null;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Auth Endpoints
  static Future<bool> register(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> login(String emailOrUsername, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email_or_username': emailOrUsername,
          'password': password,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<User?> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<User?> getProfile(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/social/profile/$userId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<User?> updateProfile({String? bio, dynamic avatar}) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/social/profile/edit'));
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      if (bio != null) {
        request.fields['bio'] = bio;
      }
      if (avatar != null) {
        request.files.add(await http.MultipartFile.fromPath('avatar', avatar.path));
      }
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Songs Catalog Endpoints
  static Future<List<Song>> getSongs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/social/songs'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['songs'] as List).map((s) => Song.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<String?> separateYoutubeSong(String youtubeUrl) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/separate'));
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.fields['youtube_url'] = youtubeUrl;
      request.fields['create_video'] = 'false'; // Separar solo audios por defecto

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['job_id'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> checkJobStatus(String jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status/$jobId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Lyrics endpoint
  static Future<List<dynamic>?> getLyricsJson(String lyricsUrl) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$lyricsUrl'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Covers Endpoints
  static Future<List<Cover>> getCovers({int? userId, String feedType = 'global'}) async {
    try {
      String path = '$baseUrl/api/social/covers?feed_type=$feedType';
      if (userId != null) {
        path += '&user_id=$userId';
      }
      final response = await http.get(Uri.parse(path), headers: _headers);
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List).map((c) => Cover.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Cover?> publishCover({
    required String title,
    String description = '',
    required int duration,
    String? jobId,
    String? vocalsFilePath,
    double vocalVolume = 1.0,
    double instrumentalVolume = 1.0,
    double reverb = 0.0,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/social/covers'));
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['duration'] = duration.toString();
      if (jobId != null) {
        request.fields['job_id'] = jobId;
      }
      request.fields['effects_vocal_volume'] = vocalVolume.toString();
      request.fields['effects_instrumental_volume'] = instrumentalVolume.toString();
      request.fields['effects_reverb'] = reverb.toString();

      if (vocalsFilePath != null && vocalsFilePath.isNotEmpty) {
        try {
          request.files.add(await http.MultipartFile.fromPath('vocals_file', vocalsFilePath));
        } catch (_) {}
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return Cover.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> likeCover(int coverId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/social/like/$coverId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Rooms Endpoints
  static Future<List<Room>> getRooms() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/rooms/'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List).map((r) => Room.fromJson(r)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Room?> createRoom(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/rooms/create'),
        headers: _headers,
        body: jsonEncode({'name': name}),
      );
      if (response.statusCode == 200) {
        return Room.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
