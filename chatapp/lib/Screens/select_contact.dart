import 'package:chatapp/CustomUI/button_card.dart';
import 'package:chatapp/CustomUI/contact_card.dart';
import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/Screens/create_group.dart';
import 'package:chatapp/Screens/individual_page.dart';
import 'package:chatapp/Services/chat_service.dart';
import 'package:flutter/material.dart';

class SelectContact extends StatefulWidget {
  const SelectContact({super.key, this.sourceChat});

  final ChatModel? sourceChat;

  @override
  State<SelectContact> createState() => _SelectContactState();
}

class _SelectContactState extends State<SelectContact> {
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
        // Filter out the current user from the list
        users = fetchedUsers
            .where((user) => user['id'] != widget.sourceChat?.id)
            .toList();
        isLoading = false;
      });
      print("✅ Successfully loaded ${users.length} contacts");
    } catch (e) {
      print('❌ Error loading users: $e');
      setState(() {
        users = [];
        isLoading = false;
      });
    }
  }

  void handleContactTap(Map<String, dynamic> contact) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Opening chat..."),
            ],
          ),
        ),
      );

      // Create or find existing chat
      final result = await ChatService.createOrFindIndividualChat(
        sourceId: widget.sourceChat!.id!,
        targetId: contact['id'],
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (result != null && result['success'] == true) {
        // Create a chat model for the target user with the correct chat ID
        final targetChat = ChatModel(
          id: result['chatId'], // Use the chat ID returned from the API
          name: contact['name'],
          icon: contact['avatar'],
          isGroup: false,
        );

        // Navigate to individual chat page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => IndividualPage(
              chatModel: targetChat,
              sourceChat: widget.sourceChat,
            ),
          ),
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create chat. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's open
      Navigator.of(context).pop();

      print('❌ Error creating chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating chat. Please check your connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Select Contact',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              isLoading ? 'Loading...' : '${users.length} Contacts',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xff075E54),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Implement search functionality here
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "Refresh") {
                loadUsers();
              }
              print(value);
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  child: Text('Invite a friend'),
                  value: "Invite a friend",
                ),
                PopupMenuItem(child: Text('Contact'), value: "Contact"),
                PopupMenuItem(child: Text('Refresh'), value: "Refresh"),
                PopupMenuItem(child: Text('Help'), value: "Help"),
              ];
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: users.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CreateGroup(sourceChat: widget.sourceChat),
                        ),
                      );
                    },
                    child: ButtonCard(name: 'New Group', icon: Icons.group_add),
                  );
                } else if (index == 1) {
                  return ButtonCard(
                    name: 'New Contact',
                    icon: Icons.person_add,
                  );
                }

                final user = users[index - 2];
                return ContactCard(
                  contact: ChatModel(
                    id: user['id'],
                    name: user['name'],
                    status: user['phone'] ?? 'Available',
                    icon: user['avatar'],
                  ),
                  onTap: () => handleContactTap(user),
                );
              },
            ),
    );
  }
}
