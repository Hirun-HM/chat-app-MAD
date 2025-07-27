import 'dart:convert';

import 'package:chatapp/CustomUI/own_file_card.dart';
import 'package:chatapp/CustomUI/own_message_card.dart';
import 'package:chatapp/CustomUI/reply_file_card.dart';
import 'package:chatapp/CustomUI/reply_message.dart';
import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/Model/message_model.dart';
import 'package:chatapp/Screens/camera_screen.dart';
import 'package:chatapp/Screens/camera_view.dart';
import 'package:chatapp/Screens/share_contact_screen.dart';
import 'package:chatapp/Screens/qr_scanner_screen.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;


import 'package:socket_io_client/socket_io_client.dart' as IO;

class IndividualPage extends StatefulWidget {
  const IndividualPage({super.key, this.chatModel, this.sourceChat});

  final ChatModel? chatModel;
  final ChatModel? sourceChat;
  @override
  State<IndividualPage> createState() => _IndividualPageState();
}

class _IndividualPageState extends State<IndividualPage>
    with WidgetsBindingObserver {
  bool isEmojiVisible = false;
  FocusNode textFieldFocusNode = FocusNode();
  late IO.Socket socket;
  TextEditingController textFieldController = TextEditingController();
  bool sendButton = false;
  List<MessageModel> messages = [];
  ImagePicker _picker = ImagePicker();
  XFile? file;
  int popTime = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    connect();

    textFieldFocusNode.addListener(() {
      if (textFieldFocusNode.hasFocus) {
        setState(() {
          isEmojiVisible = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && socket.connected) {
      
      print("📱 App resumed in individual chat - marking messages as read");
      socket.emit("enter_chat", {
        "userId": widget.sourceChat?.id,
        "chatId": widget.chatModel?.id,
      });
    }
  }

  void connect() {
    socket = IO.io(
      "http://192.168.1.3:8000",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      print("✅ Socket connected with ID: ${socket.id}");
      socket.emit("signin", widget.sourceChat?.id);

      
      if (widget.chatModel?.id != null) {
        socket.emit("join_chat", {
          "chatId": widget.chatModel!.id,
          "userId": widget.sourceChat?.id,
        });

        
        socket.emit("enter_chat", {
          "userId": widget.sourceChat?.id,
          "chatId": widget.chatModel?.id,
        });
      }

      
      socket.emit("get_chat_history_by_id", {
        "chatId": widget.chatModel?.id,
        "userId": widget.sourceChat?.id,
      });

      socket.on("message", (msg) {
        print("📨 Received message: $msg");
        
        if (msg['senderId'] != widget.sourceChat?.id) {
          setMessage(
            "destination",
            msg['message'],
            msg['path'] ?? '',
            msg['id'],
          );
        }

        
        if (msg['id'] != null) {
          socket.emit("message_read", {
            "messageId": msg['id'],
            "userId": widget.sourceChat?.id,
            "chatId": widget.chatModel?.id,
          });
        }
      });

     
      socket.on("notification", (data) {
        print("🔔 Received notification: $data");
        showNotificationSnackBar(data['sender'], data['message']);
      });

      
      socket.on("message_read_receipt", (data) {
        print("👁️ Message read receipt: $data");
        updateMessageReadStatus(data['messageId'], true);
      });

      socket.on("message_sent", (data) {
        print("✅ Message sent confirmation: ${data['id']}");
       
        if (data['id'] != null) {
          setState(() {
            
            for (int i = messages.length - 1; i >= 0; i--) {
              if (messages[i].type == "source" && messages[i].id == null) {
                messages[i].id = data['id'];
                messages[i].isDelivered = true;
                break;
              }
            }
          });
        }
      });

      socket.on("chat_history", (data) {
        print(
          "📜 Received chat history with ${data['messages'].length} messages",
        );
        setState(() {
          messages.clear();
          for (var msg in data['messages']) {
            MessageModel messageModel = MessageModel(
              id: msg['id'],
              type: msg['messageType'],
              message: msg['message'],
              path: msg['path'] ?? '',
              time: DateTime.now().toString().substring(10, 16),
              isDelivered: true, 
              isRead: msg['isRead'] ?? false, 
            );
            messages.add(messageModel);
          }
        });
      });

     
      socket.on("unread_count_update", (data) {
        print("🔢 Individual page - Unread count update: $data");
       
      });
    });

    socket.onConnectError((data) {
      print("❌ Connect Error: $data");
    });

    socket.onError((data) {
      print("❌ Socket Error: $data");
    });

    socket.connect();
    print("🔄 Connecting to socket...");
  }

  void sendMessage(String message, int sourceId, int chatId, String path) {
   
    setMessage("source", message, path);

    
    socket.emit("send_chat_message", {
      "message": message,
      "senderId": sourceId,
      "chatId": chatId,
      "path": path,
    });
  }

  void setMessage(String type, String message, String path, [int? messageId]) {
    MessageModel messageModel = MessageModel(
      id: messageId,
      type: type,
      message: message,
      path: path,
      time: DateTime.now().toString().substring(10, 16),
      isDelivered: type == "source" ? false : true,
      isRead: type == "destination" ? true : false,
    );
    setState(() {
      messages.add(messageModel);
    });
  }

  // Update message read status
  void updateMessageReadStatus(int messageId, bool isRead) {
    setState(() {
      final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
      if (messageIndex != -1) {
        messages[messageIndex].isRead = isRead;
      }
    });
  }

  
  void updateMessageDeliveryStatus(int messageId, bool isDelivered) {
    setState(() {
      final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
      if (messageIndex != -1) {
        messages[messageIndex].isDelivered = isDelivered;
      }
    });
  }


  void showNotificationSnackBar(String sender, String message) {
    if (mounted) {
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
                    Text(sender, style: TextStyle(fontWeight: FontWeight.bold)),
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
  }

  // Simplified image picker methods without permission_handler
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          file = pickedFile;
        });
        Navigator.pop(context); 
        print('Image selected: ${pickedFile.path}');

        
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image selected successfully!')));
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to pick image. Please check app permissions in settings.',
          ),
        ),
      );
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          file = pickedFile;
        });
        Navigator.pop(context); 
        print('Image captured: ${pickedFile.path}');

        // Show success message
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Photo captured successfully!')));
      }
    } catch (e) {
      print('Error capturing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to capture image. Please check camera permissions in settings.',
          ),
        ),
      );
    }
  }

  void onImageSend(String path, String message) async {
    print("working hey there $message");
    for (int i = 0; i < popTime; i++) {
      Navigator.pop(context); // Close the bottom sheet or camera view
    }
    setState(() {
      popTime = 0;
    });
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("http://192.168.56.1/route/addimage"),
    );
    request.files.add(await http.MultipartFile.fromPath('image', path));
    request.headers.addAll({'Content-Type': 'multipart/form-data'});
    http.StreamedResponse response = await request.send();
    var httpResponse = await http.Response.fromStream(response);
    var data = json.decode(httpResponse.body);
    print(data['path']);
    print(response.statusCode);
    setMessage("source", message, path);
    socket.emit("message", {
      "message": message,
      "sourceId": widget.sourceChat?.id,
      "targetId": widget.chatModel?.id,
      "path": path,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Image.asset(
          'assets/whatsapp_back.jpg',
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          fit: BoxFit.cover,
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            titleSpacing: 0,
            backgroundColor: const Color(0xff075E54),
            leadingWidth: 100,
            leading: InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, color: Colors.white),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blueGrey,
                    child: SvgPicture.asset(
                      (widget.chatModel?.isGroup ?? false)
                          ? 'assets/groups.svg'
                          : 'assets/person.svg',
                      width: 38,
                      height: 38,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            title: InkWell(
              onTap: () {},
              child: Container(
                margin: EdgeInsets.all(5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chatModel?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'last seen today at 12:00 PM',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.video_call), onPressed: () {}),
              IconButton(icon: const Icon(Icons.call), onPressed: () {}),
              PopupMenuButton<String>(
                onSelected: (value) {
                  _handleMenuSelection(value);
                },
                itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                      child: Text('View Contact'),
                      value: "View Contact",
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
                      child: Text('links, media, and docs'),
                      value: "links, media, and docs",
                    ),
                    PopupMenuItem(child: Text('Search'), value: "Search"),
                    PopupMenuItem(
                      child: Text('Mute Notifications'),
                      value: "Mute Notifications",
                    ),
                    PopupMenuItem(child: Text('Wallpaper'), value: "Wallpaper"),
                  ];
                },
              ),
            ],
          ),
          body: Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: WillPopScope(
              child: Column(
                children: [
                  Expanded(
                    // height: MediaQuery.of(context).size.height - 144,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        if (messages[index].type == "source") {
                          if (messages[index].path.length > 0) {
                            return OwnFileCard(
                              path: messages[index].path,
                              message: messages[index].message,
                              time: messages[index].time,
                            );
                          } else {
                            return OwnMessageCard(
                              messageModel: messages[index],
                            );
                          }
                        } else {
                          if (messages[index].path.length > 0) {
                            return ReplyFileCard(
                              path: messages[index].path,
                              message: messages[index].message,
                              time: messages[index].time,
                            );
                          } else {
                            return ReplyMessageCard(
                              message: messages[index].message,
                            );
                          }
                        }
                      },
                    ),
                    
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width - 55,
                              child: Card(
                                margin: EdgeInsets.only(
                                  left: 2,
                                  right: 2,
                                  bottom: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: TextFormField(
                                  controller: textFieldController,
                                  focusNode: textFieldFocusNode,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                  keyboardType: TextInputType.multiline,
                                  maxLines: 5,
                                  minLines: 1,
                                
                                  onChanged: (value) {
                                    if (value.length > 0) {
                                      setState(() {
                                        sendButton = true;
                                      });
                                    } else {
                                      setState(() {
                                        sendButton = false;
                                      });
                                    }
                                  },
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Type a message',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    prefixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          textFieldFocusNode.unfocus();
                                          textFieldFocusNode.canRequestFocus =
                                              false;
                                          isEmojiVisible = !isEmojiVisible;
                                        });
                                      },
                                      icon: Icon(
                                        Icons.emoji_emotions,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.attach_file,
                                            color: Colors.blueGrey,
                                          ),
                                          onPressed: () {
                                            showModalBottomSheet(
                                              backgroundColor:
                                                  Colors.transparent,
                                              context: context,
                                              builder: (builder) =>
                                                  bottomSheet(),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.camera_alt,
                                            color: Colors.blueGrey,
                                          ),
                                          onPressed: () async {
                                            setState(() {
                                              popTime = 3;
                                            });
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (builder) =>
                                                    CameraScreen(
                                                      onImageSend: onImageSend,
                                                    ),
                                              ),
                                            );
                                          },
                                          // Use the new method here too
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: const Color(0xff128C7E),
                              child: IconButton(
                                icon: Icon(
                                  sendButton ? Icons.send : Icons.mic,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  
                                  if (sendButton &&
                                      widget.sourceChat?.id != null &&
                                      widget.chatModel?.id != null &&
                                      textFieldController.text
                                          .trim()
                                          .isNotEmpty) {
                                    sendMessage(
                                      textFieldController.text.trim(),
                                      widget.sourceChat!.id!,
                                      widget.chatModel!.id!,
                                      '', 
                                    );
                                   
                                    textFieldController.clear();
                                    setState(() {
                                      sendButton = false;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        isEmojiVisible
                            ? emojiPicker()
                            : Container(), 
                      ],
                    ),
                  ),
                ],
              ),
              onWillPop: () {
                if (isEmojiVisible) {
                  setState(() {
                    isEmojiVisible = false;
                  });
                } else {
                  Navigator.pop(context);
                }
                return Future.value(false);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget bottomSheet() {
    return Container(
      height: 278,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Card(
        margin: EdgeInsets.all(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(width: 10),
                  increation(
                    icon: Icons.insert_drive_file,
                    color: Colors.indigo,
                    text: 'Document',
                    onTap: () {},
                  ),
                  SizedBox(width: 40),
                  increation(
                    icon: Icons.camera_alt,
                    color: Colors.red,
                    text: 'Camera',
                    onTap: () async {
                      setState(() {
                        popTime = 2;
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (builder) => CameraScreen(
                            onImageSend: onImageSend, // Pass the new method
                          ),
                        ),
                      );
                    }, // Use the new method
                  ),
                  SizedBox(width: 40),
                  increation(
                    icon: Icons.photo_library,
                    color: Colors.purple,
                    text: 'Gallery',
                    onTap: () async {
                      setState(() {
                        popTime = 2;
                      });
                      file = await _picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (file != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (Builder) => CameraView(
                              path: file!.path,
                              onImageSend: onImageSend, // Pass the new method),
                            ),
                          ),
                        );
                      }
                    }, // Use the new method
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(width: 10),
                  increation(
                    icon: Icons.headset,
                    color: Colors.orange,
                    text: 'Audio',
                    onTap: () {},
                  ),
                  SizedBox(width: 40),
                  increation(
                    icon: Icons.location_on,
                    color: Colors.pinkAccent,
                    text: 'Location',
                    onTap: () {},
                  ),
                  SizedBox(width: 40),
                  increation(
                    icon: Icons.person,
                    color: Colors.blue,
                    text: 'Contact',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget increation({
    required icon,
    required Color color,
    required String text,
    GestureTapCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Icon(icon, size: 29, color: Colors.white),
          ),
          SizedBox(height: 5),
          Text(text),
        ],
      ),
    );
  }

  Widget emojiPicker() {
    return SizedBox(
      height: 250,
      width: MediaQuery.of(context).size.width,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          print(emoji);
          setState(() {
            textFieldController.text += emoji.emoji;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    socket.dispose();
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'Share Contact':
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
        break;
      case 'Scan QR Code':
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
        break;
      default:
        print('Selected: $value');
        break;
    }
  }
}
