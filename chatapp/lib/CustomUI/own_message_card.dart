import 'package:flutter/material.dart';
import '../Model/message_model.dart';

class OwnMessageCard extends StatelessWidget {
  const OwnMessageCard({super.key, this.message, this.time, this.messageModel});
  final String? message;
  final String? time;
  final MessageModel? messageModel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 45,
        ),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          color: Color(0xffdcf8c6),
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 10,
                  right: 60,
                  top: 10,
                  bottom: 20,
                ),
                child: Text(message ?? messageModel?.message ?? ''),
              ),
              Positioned(
                bottom: 4,
                right: 5,
                child: Row(
                  children: [
                    Text(
                      time ?? messageModel?.time ?? '00:00',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    SizedBox(width: 5),
                    _buildStatusIcon(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (messageModel == null) {
      return Icon(Icons.done, size: 16, color: Colors.grey);
    }

    if (messageModel!.isRead) {
      // Blue double tick for read
      return Icon(Icons.done_all, size: 16, color: Colors.blue);
    } else if (messageModel!.isDelivered) {
      // Gray double tick for delivered but not read
      return Icon(Icons.done_all, size: 16, color: Colors.grey);
    } else {
      // Single gray tick for sent but not delivered
      return Icon(Icons.done, size: 16, color: Colors.grey);
    }
  }
}
