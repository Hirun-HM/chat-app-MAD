import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Model/chat_model.dart';

class ChatService {
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // Fetch chats for a specific user
  static Future<List<ChatModel>> getChats(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => ChatModel.fromJson(json)).toList();
      } else {
        print('Failed to load chats: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching chats: $e');
      return [];
    }
  }

  // Fetch all users
  static Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.cast<Map<String, dynamic>>();
      } else {
        print('Failed to load users: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }
}
