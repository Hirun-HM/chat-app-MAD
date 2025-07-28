import 'dart:async';
import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/NewScreens/call_screen.dart';
import 'package:chatapp/Pages/camera_page.dart';
import 'package:chatapp/Pages/chat_page.dart';
import 'package:chatapp/Services/chat_service.dart';
import 'package:chatapp/Screens/settings_screen.dart';
import 'package:chatapp/Screens/qr_scanner_screen.dart';
import 'package:chatapp/Screens/share_contact_screen.dart';
import 'package:chatapp/config/app_config.dart' as app_config;
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.chatmodels, this.sourceChat});
  final List<ChatModel>? chatmodels;
  final ChatModel? sourceChat;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  TabController? _controller;
  List<ChatModel> chats = [];
  bool isLoading = true;
  late IO.Socket socket;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TabController(length: 4, vsync: this, initialIndex: 1);
    connectSocket();
    
    refreshChats();

    
    _refreshTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        print("⏰ Periodic refresh triggered");
        forceRefreshChats();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Refresh chats when app resumes
      print("📱 App resumed - refreshing chat list");
      refreshChats();
    }
  }

  void connectSocket() {
    socket = IO.io(
      app_config.Config.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      print("🏠 Home screen socket connected");
      socket.emit("signin", widget.sourceChat?.id);

      // Listen for chat list updates
      socket.on("chat_list_update", (data) {
        print("📋 Chat list update received: $data");

        // Update the specific chat in the list instead of reloading everything
        if (data['chatId'] != null) {
          setState(() {
            final chatIndex = chats.indexWhere(
              (chat) => chat.id == data['chatId'],
            );
            if (chatIndex != -1) {
              // Update existing chat
              final updatedChat = chats[chatIndex];
              updatedChat.currentMessage =
                  data['lastMessage'] ?? updatedChat.currentMessage;
              updatedChat.time = _formatTime(data['time']) ?? updatedChat.time;
              updatedChat.unreadCount = data['unreadCount'] ?? 0;

              // Update message status information
              updatedChat.isLastMessageFromCurrentUser =
                  data['isLastMessageFromCurrentUser'] ?? false;
              updatedChat.lastMessageReadByOthers =
                  data['lastMessageReadByOthers'] ?? false;
              updatedChat.lastSenderId = data['senderId'];

              // Only update sender if it's not the current user
              if (data['senderId'] != widget.sourceChat?.id) {
                updatedChat.currentMessage =
                    data['lastMessage'] ?? updatedChat.currentMessage;
              }

              // Move this chat to the top (most recent)
              chats.removeAt(chatIndex);
              chats.insert(0, updatedChat);
            } else {
              // If chat not found, refresh the entire list
              print("🔄 Chat not found in list, refreshing...");
              forceRefreshChats();
            }
          });
        } else {
          // Fallback to full refresh if no chatId provided
          forceRefreshChats();
        }
      });

      // Listen for unread count updates
      socket.on("unread_count_update", (data) {
        print("🔢 Unread count update: $data");
        if (data['chatId'] != null && data['userId'] == widget.sourceChat?.id) {
          setState(() {
            final chatIndex = chats.indexWhere(
              (chat) => chat.id == data['chatId'],
            );
            if (chatIndex != -1) {
              chats[chatIndex].unreadCount = data['unreadCount'] ?? 0;
              print(
                "✅ Updated unread count for chat ${data['chatId']}: ${data['unreadCount']}",
              );
            }
          });
        }
      });

      // Listen for new messages in other chats (when not actively in that chat)
      socket.on("message", (data) {
        print("📨 Home screen received message notification: $data");

        // Only handle if this message is for a different chat than what user is currently viewing
        if (data['chatId'] != null &&
            data['senderId'] != widget.sourceChat?.id) {
          setState(() {
            final chatIndex = chats.indexWhere(
              (chat) => chat.id == data['chatId'],
            );
            if (chatIndex != -1) {
              final updatedChat = chats[chatIndex];
              updatedChat.currentMessage =
                  data['message'] ?? updatedChat.currentMessage;
              updatedChat.time =
                  _formatTime(data['sentAt']) ?? updatedChat.time;
              updatedChat.unreadCount = (updatedChat.unreadCount ?? 0) + 1;
              updatedChat.isLastMessageFromCurrentUser = false;
              updatedChat.lastSenderId = data['senderId'];

              // Move this chat to the top (most recent)
              chats.removeAt(chatIndex);
              chats.insert(0, updatedChat);

              print(
                "✅ Updated chat list for new message in chat ${data['chatId']}",
              );
            } else {
              // New chat might have been created, refresh the list
              print("🔄 New message in unknown chat, refreshing list...");
              forceRefreshChats();
            }
          });
        }
      });

      // Listen for notifications
      socket.on("notification", (data) {
        print("🔔 Home screen received notification: $data");

        // Show notification to user
        if (mounted && data['type'] == 'new_message') {
          final message = data['message']?.toString() ?? 'New message';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.notifications, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data['sender'] ?? 'New Message',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          message.length > 50
                              ? '${message.substring(0, 50)}...'
                              : message,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xff075E54),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });

      // Listen for user status changes
      socket.on("user_status_change", (data) {
        print("👤 User status change: $data");

        // For now, just log the status change
        // We can implement more detailed status updates later
        if (data['userId'] != null) {
          print("User ${data['userId']} is now ${data['status']}");
        }
      });
    });

    socket.onConnectError((data) {
      print("❌ Home screen socket error: $data");
    });

    socket.onDisconnect((_) {
      print("🔌 Home screen socket disconnected");
    });
  }

  void loadChats() async {
    if (widget.sourceChat?.id != null) {
      try {
        final fetchedChats = await ChatService.getChats(widget.sourceChat!.id!);
        setState(() {
          chats = fetchedChats;
          isLoading = false;
        });
        print("✅ Successfully loaded ${fetchedChats.length} chats");
      } catch (e) {
        print('❌ Error loading chats: $e');
        setState(() {
          chats = widget.chatmodels ?? [];
          isLoading = false;
        });
      }
    } else {
      setState(() {
        chats = widget.chatmodels ?? [];
        isLoading = false;
      });
    }
  }

  // Method to refresh chats
  void refreshChats() {
    print("🔄 Refreshing chat list...");
    setState(() {
      isLoading = true;
    });
    loadChats();
  }

  // Force refresh chats (for use in socket events)
  void forceRefreshChats() {
    print("🔄 Force refreshing chat list from socket event...");
    loadChats();
  }

  // Helper method to format time like WhatsApp
  String? _formatTime(String? timestamp) {
    if (timestamp == null) return null;

    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();

      // If it's today, show time (HH:MM)
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      }

      // If it's this week, show day name
      final daysDiff = now.difference(date).inDays;
      if (daysDiff < 7) {
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return weekdays[date.weekday - 1];
      }

      // Otherwise show date
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      print('Error formatting time: $e');
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            // Refresh chats before navigating back
            refreshChats();
            // Add a small delay to ensure refresh completes
            Future.delayed(Duration(milliseconds: 500), () {
              Navigator.pop(context);
            });
          },
          icon: Icon(Icons.arrow_back),
          color: Colors.white,
          tooltip: 'Back (with refresh)',
        ),
        title: Text(
          'Whatsapp Clone',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xff075E54),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.search),
            color: Colors.white,
          ),
          IconButton(
            onPressed: refreshChats,
            icon: Icon(Icons.refresh),
            color: Colors.white,
            tooltip: 'Refresh chats',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              print(value);
              if (value == "Settings") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SettingsScreen(sourceChat: widget.sourceChat),
                  ),
                );
              } else if (value == "Scan QR Code") {
                if (widget.sourceChat != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QRScannerScreen(
                        currentUserId: widget.sourceChat!.id!,
                        currentUser: widget.sourceChat!,
                      ),
                    ),
                  );
                }
              } else if (value == "Share Contact") {
                if (widget.sourceChat != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShareContactScreen(
                        userId: widget.sourceChat!.id!,
                        userName: widget.sourceChat!.name ?? 'Unknown User',
                      ),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem(child: Text('New Group'), value: "New Group"),
                PopupMenuItem(
                  child: Text('New Broadcast'),
                  value: "New Broadcast",
                ),
                PopupMenuItem(
                  child: Text('Share Contact'),
                  value: "Share Contact",
                ),
                PopupMenuItem(
                  child: Text('Scan QR Code'),
                  value: "Scan QR Code",
                ),
                PopupMenuItem(
                  child: Text('Linked Devices'),
                  value: "Linked Devices",
                ),
                PopupMenuItem(
                  child: Text('Starred Messages'),
                  value: "Starred Messages",
                ),
                PopupMenuItem(child: Text('Settings'), value: "Settings"),
              ];
            },
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          indicatorColor: Color(0xff25D366),
          indicatorWeight: 3,
          labelColor: Color(0xff25D366),
          unselectedLabelColor: Colors.white,
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),

          tabs: [
            Tab(icon: Icon(Icons.camera_alt)),
            Tab(text: 'CHATS'),
            Tab(text: 'STATUS'),
            Tab(text: 'CALLS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          CameraPage(),
          isLoading
              ? Center(child: CircularProgressIndicator())
              : ChatPage(
                  chats: chats,
                  sourceChat: widget.sourceChat,
                  onRefresh: refreshChats,
                ),
          Center(child: Text('Status')),
          CallScreen(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    if (socket.connected) {
      socket.disconnect();
    }
    socket.dispose();
    _controller?.dispose();
    super.dispose();
  }
}
