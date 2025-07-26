import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/NewScreens/call_screen.dart';
import 'package:chatapp/Pages/camera_page.dart';
import 'package:chatapp/Pages/chat_page.dart';
import 'package:chatapp/Services/chat_service.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.chatmodels, this.sourceChat});
  final List<ChatModel>? chatmodels;
  final ChatModel? sourceChat;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  TabController? _controller;
  List<ChatModel> chats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 4, vsync: this, initialIndex: 1);
    loadChats();
  }

  void loadChats() async {
    if (widget.sourceChat?.id != null) {
      try {
        final fetchedChats = await ChatService.getChats(widget.sourceChat!.id!);
        setState(() {
          chats = fetchedChats;
          isLoading = false;
        });
      } catch (e) {
        print('Error loading chats: $e');
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
    setState(() {
      isLoading = true;
    });
    loadChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          PopupMenuButton<String>(
            onSelected: (value) {
              print(value);
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
}
