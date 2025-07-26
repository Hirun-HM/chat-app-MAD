class ChatModel {
  String? name;
  String? icon;
  bool? isGroup;
  String? currentMessage;
  String? time;
  String? status;
  bool select;
  int? id;
  int? unreadCount;
  int? lastSenderId;
  bool lastMessageReadByOthers;
  bool isLastMessageFromCurrentUser;

  ChatModel({
    this.name,
    this.icon,
    this.isGroup,
    this.currentMessage,
    this.time,
    this.status,
    this.select = false,
    this.id,
    this.unreadCount = 0,
    this.lastSenderId,
    this.lastMessageReadByOthers = false,
    this.isLastMessageFromCurrentUser = false,
  });

  // Factory constructor to create ChatModel from API response
  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'],
      name: json['name'] ?? json['display_name'],
      icon: json['icon'],
      isGroup: json['type'] == 'group',
      currentMessage:
          json['currentMessage'] ?? json['last_message'] ?? 'No messages yet',
      time: json['time'],
      status: 'offline',
      unreadCount: json['unread_count'] ?? 0,
      lastSenderId: json['lastSenderId'],
      lastMessageReadByOthers: json['lastMessageReadByOthers'] ?? false,
      isLastMessageFromCurrentUser:
          json['isLastMessageFromCurrentUser'] ?? false,
    );
  }
}
