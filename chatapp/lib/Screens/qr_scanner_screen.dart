import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:chatapp/Model/chat_model.dart';
import 'package:chatapp/Screens/individual_page.dart';
import 'package:http/http.dart' as http;

class QRScannerScreen extends StatefulWidget {
  final int currentUserId;
  final ChatModel currentUser;

  const QRScannerScreen({
    Key? key,
    required this.currentUserId,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _processScannedData(String data) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // Parse the QR code data
      final Map<String, dynamic> contactData = json.decode(data);

      if (contactData['type'] == 'contact') {
        final userId = contactData['userId'];
        final name = contactData['name'];
        final phone = contactData['phone'];

        // Create a chat model for the scanned contact
        final ChatModel scannedUser = ChatModel(
          id: userId,
          name: name,
          icon: "person.svg",
          isGroup: false,
          time: DateTime.now().toIso8601String(),
          currentMessage: "Tap to start chatting",
        );

        // Show confirmation dialog
        _showContactConfirmation(scannedUser, phone);
      } else {
        _showError('Invalid QR code format');
      }
    } catch (e) {
      _showError('Failed to process QR code: ${e.toString()}');
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  void _showContactConfirmation(ChatModel contact, String phone) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2C34),
          title: const Text(
            'Add Contact',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 15),
              Text(
                contact.name ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                phone,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 15),
              const Text(
                'Would you like to start a chat with this contact?',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Resume scanning by resetting the processing flag
                setState(() {
                  isProcessing = false;
                });
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startChat(contact);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF075E54),
              ),
              child: const Text(
                'Start Chat',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startChat(ChatModel contact) async {
    try {
      // Create or get existing chat using the correct endpoint
      final response = await http.post(
        Uri.parse('http://192.168.1.3:8000/api/chats/individual'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sourceId': widget.currentUserId,
          'targetId': contact.id,
        }),
      );

      if (response.statusCode == 200) {
        final chatData = json.decode(response.body);
        final chatModel = ChatModel(
          id: chatData['chatId'],
          name: contact.name,
          icon: contact.icon,
          isGroup: false,
          time: DateTime.now().toIso8601String(),
          currentMessage: "Start your conversation",
        );

        // Navigate to chat
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => IndividualPage(
              chatModel: chatModel,
              sourceChat: widget.currentUser,
            ),
          ),
        );
      } else {
        _showError('Failed to create chat');
      }
    } catch (e) {
      _showError('Error creating chat: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    // Reset processing flag to allow scanning again
    setState(() {
      isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2C34),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Mobile Scanner View
          MobileScanner(
            controller: controller,
            onDetect: (BarcodeCapture capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !isProcessing) {
                  _processScannedData(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Scanner Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: const Color(0xFF075E54),
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),

          // Instructions
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Point your camera at a QR code to scan a contact',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Processing Indicator
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF075E54)),
                    SizedBox(height: 20),
                    Text(
                      'Processing QR Code...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Flash Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {
                      controller.toggleTorch();
                    },
                    icon: const Icon(
                      Icons.flash_on,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),

                // Camera Flip
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {
                      controller.switchCamera();
                    },
                    icon: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(
          rect.left,
          rect.top,
          rect.left + borderRadius,
          rect.top,
        )
        ..lineTo(rect.right, rect.top);
    }

    return _getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final _borderLength = borderLength > cutOutSize / 2 + borderWidth * 2
        ? borderWidthSize / 2
        : borderLength;
    final _cutOutSize = cutOutSize < width ? cutOutSize : width - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - _cutOutSize / 2 + borderOffset,
      rect.top + height / 2 - _cutOutSize / 2 + borderOffset,
      _cutOutSize - borderOffset * 2,
      _cutOutSize - borderOffset * 2,
    );

    // Draw overlay
    canvas.saveLayer(rect, backgroundPaint);
    canvas.drawRect(rect, backgroundPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      boxPaint,
    );
    canvas.restore();

    // Draw border
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      borderPaint,
    );

    // Draw corners
    final path = Path();
    // Top-left corner
    path.moveTo(cutOutRect.left - borderOffset, cutOutRect.top + _borderLength);
    path.lineTo(cutOutRect.left - borderOffset, cutOutRect.top + borderRadius);
    path.quadraticBezierTo(
      cutOutRect.left - borderOffset,
      cutOutRect.top - borderOffset,
      cutOutRect.left + borderRadius,
      cutOutRect.top - borderOffset,
    );
    path.lineTo(cutOutRect.left + _borderLength, cutOutRect.top - borderOffset);

    // Top-right corner
    path.moveTo(
      cutOutRect.right - _borderLength,
      cutOutRect.top - borderOffset,
    );
    path.lineTo(cutOutRect.right - borderRadius, cutOutRect.top - borderOffset);
    path.quadraticBezierTo(
      cutOutRect.right + borderOffset,
      cutOutRect.top - borderOffset,
      cutOutRect.right + borderOffset,
      cutOutRect.top + borderRadius,
    );
    path.lineTo(
      cutOutRect.right + borderOffset,
      cutOutRect.top + _borderLength,
    );

    // Bottom-right corner
    path.moveTo(
      cutOutRect.right + borderOffset,
      cutOutRect.bottom - _borderLength,
    );
    path.lineTo(
      cutOutRect.right + borderOffset,
      cutOutRect.bottom - borderRadius,
    );
    path.quadraticBezierTo(
      cutOutRect.right + borderOffset,
      cutOutRect.bottom + borderOffset,
      cutOutRect.right - borderRadius,
      cutOutRect.bottom + borderOffset,
    );
    path.lineTo(
      cutOutRect.right - _borderLength,
      cutOutRect.bottom + borderOffset,
    );

    // Bottom-left corner
    path.moveTo(
      cutOutRect.left + _borderLength,
      cutOutRect.bottom + borderOffset,
    );
    path.lineTo(
      cutOutRect.left + borderRadius,
      cutOutRect.bottom + borderOffset,
    );
    path.quadraticBezierTo(
      cutOutRect.left - borderOffset,
      cutOutRect.bottom + borderOffset,
      cutOutRect.left - borderOffset,
      cutOutRect.bottom - borderRadius,
    );
    path.lineTo(
      cutOutRect.left - borderOffset,
      cutOutRect.bottom - _borderLength,
    );

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
    );
  }
}
