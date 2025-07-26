import 'package:chatapp/CustomUI/custom_card.dart';
import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/Screens/select_contact.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.chats, this.sourceChat, this.onRefresh});
  final List<ChatModel>? chats;
  final ChatModel? sourceChat;
  final VoidCallback? onRefresh;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SelectContact(sourceChat: widget.sourceChat),
            ),
          );
        },
        backgroundColor: const Color(0xff128C7E),
        child: const Icon(Icons.chat),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (widget.onRefresh != null) {
            widget.onRefresh!();
          }
        },
        child: ListView.builder(
          itemCount: widget.chats?.length ?? 0,
          itemBuilder: (context, index) {
            return CustomCard(
              chatModel: widget.chats![index],
              sourceChat: widget.sourceChat,
              onChatDeleted: widget.onRefresh,
            );
          },
        ),
      ),
    );
  }
}
