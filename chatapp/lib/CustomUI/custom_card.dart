import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/Screens/individual_page.dart';
import 'package:chatapp/Services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CustomCard extends StatelessWidget {
  const CustomCard({
    super.key,
    this.chatModel,
    this.sourceChat,
    this.onChatDeleted,
  });

  final ChatModel? chatModel;
  final ChatModel? sourceChat;
  final VoidCallback? onChatDeleted;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        // Navigate to individual page and wait for return
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                IndividualPage(chatModel: chatModel, sourceChat: sourceChat),
          ),
        );
        // When returning from individual page, the home screen socket should have
        // already received the unread count update, but we can trigger a small delay
        // to ensure the UI is updated
        Future.delayed(Duration(milliseconds: 100), () {
          // The home screen's socket listener should handle the unread count update
        });
      },
      onLongPress: () {
        _showDeleteDialog(context);
      },
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blueGrey,
              child: SvgPicture.asset(
                (chatModel?.isGroup ?? false)
                    ? 'assets/groups.svg'
                    : 'assets/person.svg',
                width: 38,
                height: 38,
                color: Colors.white,
              ),
            ),
            title: Text(
              chatModel?.name ?? 'Unknown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Row(
              children: [
                // Only show tick marks if the current user sent the last message
                if (chatModel?.isLastMessageFromCurrentUser == true) ...[
                  _buildMessageStatusIcon(),
                  SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    chatModel?.currentMessage ?? 'No message',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chatModel?.time ?? '00:00',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                SizedBox(height: 4),
                if ((chatModel?.unreadCount ?? 0) > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xff25D366),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${chatModel?.unreadCount}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20, left: 80),
            child: Divider(thickness: 1, color: Colors.grey[300]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatusIcon() {
    if (chatModel?.lastMessageReadByOthers == true) {
      // Blue double tick for read messages
      return Icon(Icons.done_all, size: 16, color: Colors.blue);
    } else {
      // Gray double tick for delivered but not read messages
      return Icon(Icons.done_all, size: 16, color: Colors.grey);
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Chat'),
          content: Text(
            chatModel?.isGroup == true
                ? 'Are you sure you want to ${chatModel?.name == sourceChat?.name ? "delete" : "leave"} this group?'
                : 'Are you sure you want to delete this chat with ${chatModel?.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteChat(context);
              },
              child: Text(
                chatModel?.isGroup == true &&
                        chatModel?.name != sourceChat?.name
                    ? 'Leave'
                    : 'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteChat(BuildContext context) async {
    if (chatModel?.id == null || sourceChat?.id == null) return;

    try {
      final result = await ChatService.deleteChat(
        chatModel!.id!,
        sourceChat!.id!,
      );

      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['action'] == 'left_group'
                  ? 'Left group successfully'
                  : 'Chat deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Notify parent to refresh
        if (onChatDeleted != null) {
          onChatDeleted!();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete chat'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
