import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/Screens/individual_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CustomCard extends StatelessWidget {
  const CustomCard({super.key, this.chatModel, this.sourceChat});

  final ChatModel? chatModel;
  final ChatModel? sourceChat;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                IndividualPage(chatModel: chatModel, sourceChat: sourceChat),
          ),
        );
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
                Icon(Icons.done_all, size: 16),
                SizedBox(width: 5),
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
}
