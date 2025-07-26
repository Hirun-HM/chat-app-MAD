import 'package:chatapp/Model/chat_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ContactCard extends StatelessWidget {
  final ChatModel? contact;
  final VoidCallback? onTap;

  const ContactCard({Key? key, this.contact, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 53,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: Colors.blueGrey,
                backgroundImage:
                    contact?.icon != null && contact!.icon!.isNotEmpty
                    ? NetworkImage(
                        'http://192.168.1.3:8000/uploads/${contact!.icon!}',
                      )
                    : null,
                child: contact?.icon == null || contact!.icon!.isEmpty
                    ? SvgPicture.asset(
                        'assets/person.svg',
                        width: 38,
                        height: 38,
                        color: Colors.white,
                      )
                    : null,
              ),
              contact?.select == true
                  ? Positioned(
                      bottom: 4,
                      right: 5,
                      child: CircleAvatar(
                        backgroundColor: Colors.teal,
                        radius: 10,
                        child: Icon(Icons.check, color: Colors.white, size: 18),
                      ),
                    )
                  : Container(),
            ],
          ),
        ),
        title: Text(
          contact?.name ?? 'Unknown',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          contact?.status ?? 'No status',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}
