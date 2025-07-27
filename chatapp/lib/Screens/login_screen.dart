import 'package:chatapp/CustomUI/button_card.dart';
import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/Screens/home_screen.dart';
import 'package:chatapp/Services/chat_service.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  ChatModel? sourceChat;
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  void loadUsers() async {
    try {
      final fetchedUsers = await ChatService.getUsers();
      setState(() {
        users = fetchedUsers;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Your Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xff075E54),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Make sure the server is running',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(onPressed: loadUsers, child: Text('Retry')),
                ],
              ),
            )
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return InkWell(
                  onTap: () async {
                   
                    sourceChat = ChatModel(
                      id: user['id'],
                      name: user['name'],
                      icon: user['avatar'],
                      isGroup: false,
                    );

                   
                    final chats = await ChatService.getChats(user['id']);

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (builder) => HomeScreen(
                          chatmodels: chats,
                          sourceChat: sourceChat,
                        ),
                      ),
                    );
                  },
                  child: ButtonCard(
                    name: user['name'] ?? 'Unknown User',
                    icon: Icons.person,
                  ),
                );
              },
            ),
    );
  }
}
