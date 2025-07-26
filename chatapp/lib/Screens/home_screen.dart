import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/NewScreens/call_screen.dart';
import 'package:chatapp/Pages/camera_page.dart';
import 'package:chatapp/Pages/chat_page.dart';
import 'package:chatapp/Services/chat_service.dart';
import 'package:chatapp/Screens/settings_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TabController(length: 4, vsync: this, initialIndex: 1);
    connectSocket();
    // Always refresh chats when the page loads
    refreshChats();
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
      "http://10.0.2.2:8000",
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
              loadChats();
            }
          });
        } else {
          // Fallback to full refresh if no chatId provided
          loadChats();
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
    });

    socket.onConnectError((data) {
      print("❌ Home screen socket error: $data");
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
    if (socket.connected) {
      socket.disconnect();
    }
    socket.dispose();
    _controller?.dispose();
    super.dispose();
  }
}
