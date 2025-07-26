import 'package:flutter/material.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/style.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, this.phoneNumber, this.countryCode});
  final String? phoneNumber;
  final String? countryCode;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: Text(
          "Verify ${widget.countryCode}${widget.phoneNumber}",
          style: TextStyle(
            color: Colors.teal,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.teal, size: 28),
            onPressed: () {
              // Add your action here
            },
          ),
        ],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            SizedBox(height: 20),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "We have sent an SMS with a verification code to ",
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  TextSpan(
                    text: "${widget.countryCode}${widget.phoneNumber} ",
                    style: TextStyle(fontSize: 16, color: Colors.cyan[700]),
                  ),
                  TextSpan(
                    text: "Wrong number? ",
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 15),
            OTPTextField(
              length: 5,
              width: MediaQuery.of(context).size.width,
              fieldWidth: 30,
              style: TextStyle(fontSize: 17),
              textFieldAlignment: MainAxisAlignment.spaceAround,
              fieldStyle: FieldStyle.underline,
              onCompleted: (pin) {
                print("Completed: " + pin);
              },
            ),
            SizedBox(height: 20),
            Center(
              child: Text(
                "Enter the 5-digit ",
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ),
            SizedBox(height: 30),
            Row(
              children: [
                Icon(Icons.message, color: Colors.teal, size: 28),
                SizedBox(width: 10),
                Text(
                  "Resend SMS",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(color: Colors.grey[300], thickness: 1.5, height: 40),
            SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.phone, color: Colors.teal, size: 28),
                SizedBox(width: 10),
                Text(
                  "Call me",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
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
