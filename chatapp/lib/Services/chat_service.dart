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

  // Create a new group
  static Future<Map<String, dynamic>?> createGroup({
    required String name,
    required int createdBy,
    required List<int> participants,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'createdBy': createdBy,
          'participants': participants,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to create group: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error creating group: $e');
      return null;
    }
  }

  // Mark messages as read
  static Future<bool> markMessagesAsRead(int chatId, int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages/mark-read/$chatId/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Marked ${result['markedCount']} messages as read');
        return true;
      } else {
        print('Failed to mark messages as read: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error marking messages as read: $e');
      return false;
    }
  }
}
