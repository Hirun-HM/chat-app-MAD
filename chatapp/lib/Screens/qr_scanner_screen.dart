import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/Screens/individual_page.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class QRScannerScreen extends StatefulWidget {
  final int currentUserId;
  final ChatModel currentUser;

  const QRScannerScreen({
    super.key,
    required this.currentUserId,
    required this.currentUser,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      isProcessing = true;
    });

    try {
      await _handleQRCode(code);
    } catch (e) {
      _showErrorDialog('Error processing QR code: $e');
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _handleQRCode(String qrData) async {
    // Check if it's a WhatsApp link
    if (qrData.startsWith('https://wa.me/')) {
      await _handleWhatsAppLink(qrData);
    } else {
      // Try to parse as JSON for direct contact info
      try {
        final Map<String, dynamic> contactData = json.decode(qrData);
        await _handleContactData(contactData);
      } catch (e) {
        _showErrorDialog('Invalid QR code format');
      }
    }
  }

  Future<void> _handleWhatsAppLink(String whatsAppUrl) async {
    // Extract phone number from WhatsApp URL
    final Uri uri = Uri.parse(whatsAppUrl);
    final String phoneNumber = uri.path.substring(1); // Remove leading '/'

    // Show options dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Contact Found'),
          content: Text('Phone number: $phoneNumber\n\nChoose an action:'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Open WhatsApp directly
                if (await canLaunchUrl(Uri.parse(whatsAppUrl))) {
                  await launchUrl(Uri.parse(whatsAppUrl));
                } else {
                  _showErrorDialog('Could not open WhatsApp');
                }
              },
              child: const Text('Open WhatsApp'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Add to app contacts and create chat
                await _createChatFromPhone(phoneNumber);
              },
              child: const Text('Add to App'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleContactData(Map<String, dynamic> contactData) async {
    final String? userId = contactData['userId']?.toString();
    final String? name = contactData['name'];
    final String? phoneNumber = contactData['phoneNumber'];

    if (userId == null || name == null || phoneNumber == null) {
      _showErrorDialog('Invalid contact data in QR code');
      return;
    }

    // Check if this is the same user
    if (widget.currentUserId.toString() == userId) {
      _showErrorDialog('You cannot add yourself as a contact');
      return;
    }

    // Create chat with this user
    await _createChat(userId, name, phoneNumber);
  }

  Future<void> _createChatFromPhone(String phoneNumber) async {
    try {
      // First, try to find user by phone number
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/users/phone/$phoneNumber'),
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        await _createChat(
          userData['id'].toString(),
          userData['name'],
          userData['phoneNumber'],
        );
      } else {
        _showErrorDialog(
          'User not found in the app. The person needs to register first.',
        );
      }
    } catch (e) {
      _showErrorDialog('Error finding user: $e');
    }
  }

  Future<void> _createChat(
    String userId,
    String name,
    String phoneNumber,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/chats/individual'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sourceId': widget.currentUserId,
          'targetId': int.parse(userId),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Create ChatModel for the new contact
        final newContact = ChatModel(
          id: int.parse(userId),
          name: name,
          isGroup: false,
          time: "just now",
          currentMessage: "Chat created",
          icon: "person.svg",
        );

        // Navigate to the individual chat
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => IndividualPage(
              chatModel: newContact,
              sourceChat: widget.currentUser,
            ),
          ),
        );
      } else {
        _showErrorDialog('Error creating chat: ${response.body}');
      }
    } catch (e) {
      _showErrorDialog('Error creating chat: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => cameraController.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            onPressed: () => cameraController.switchCamera(),
            icon: const Icon(Icons.camera_front),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: cameraController, onDetect: _onDetect),
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
          // Overlay with scanning frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Point your camera at a QR code to scan it',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
