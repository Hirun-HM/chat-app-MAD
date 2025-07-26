import 'package:flutter/cupertino.dart';

class MessageModel {
  String? type;
  String? message;
  String path;
  String? time;
  int? id;
  bool isRead;
  bool isDelivered;

  MessageModel({
    this.type,
    this.message,
    required this.path,
    this.time,
    this.id,
    this.isRead = false,
    this.isDelivered = false,
  });
}
