import 'package:flutter/cupertino.dart';

class MessageModel {
  String? type;
  String? message;
  String path;
  String? time;
  MessageModel({this.type, this.message, required this.path,
    this.time}) {
    ;
  }
}
