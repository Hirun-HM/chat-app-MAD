import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;

class ShareContactScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const ShareContactScreen({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<ShareContactScreen> createState() => _ShareContactScreenState();
}

class _ShareContactScreenState extends State<ShareContactScreen> {
  String? qrCodeData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    generateQRCode();
  }

  Future<void> generateQRCode() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.3:8000/api/qr-code/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          // Extract the contact data for QR generation
          final contactData = data['contactData'];
          setState(() {
            qrCodeData = json.encode(contactData);
            isLoading = false;
          });
        } else {
          setState(() {
            error = 'Failed to generate QR code';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'Failed to connect to server';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  void _shareContact() {
    // This would typically use a sharing plugin
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR code ready to share!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2C34),
        title: const Text(
          'Share Contact',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // User Info Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2C34),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Name
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'My Contact Info',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // QR Code Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  if (isLoading)
                    const Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF075E54)),
                        SizedBox(height: 20),
                        Text(
                          'Generating QR Code...',
                          style: TextStyle(color: Colors.black54, fontSize: 16),
                        ),
                      ],
                    )
                  else if (error != null)
                    Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              error = null;
                            });
                            generateQRCode();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF075E54),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  else if (qrCodeData != null)
                    Column(
                      children: [
                        QrImageView(
                          data: qrCodeData!,
                          version: QrVersions.auto,
                          size: 250.0,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Scan this QR code to add me as a contact',
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Action Buttons
            if (!isLoading && error == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Share Button
                  ElevatedButton.icon(
                    onPressed: _shareContact,
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text(
                      'Share',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF075E54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),

                  // Copy Link Button
                  ElevatedButton.icon(
                    onPressed: () {
                      if (qrCodeData != null) {
                        Clipboard.setData(ClipboardData(text: qrCodeData!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contact data copied to clipboard!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, color: Colors.white),
                    label: const Text(
                      'Copy',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
