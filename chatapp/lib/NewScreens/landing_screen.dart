import 'package:chatapp/NewScreens/login_page.dart';
import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: 50),
              Text(
                "Welcome to ChatApp",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height / 8),
              Image.asset(
                "assets/bg.png",
                color: Colors.greenAccent[700],
                height: 340,
                width: 340,
              ),
              SizedBox(height: MediaQuery.of(context).size.height / 7.5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(fontSize: 18, color: Colors.black),
                    children: [
                      TextSpan(
                        text: "Agree and continue to accept the ",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      TextSpan(
                        text: "ChatsApp Terms of Service and Privacy Policy",
                        style: TextStyle(
                          color: Colors.cyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              InkWell(
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (builder) => LoginPage()),
                    (route) => false,
                  );
                },
                child: Container(
                  width: MediaQuery.of(context).size.width - 110,
                  height: 50,
                  child: Card(
                    margin: EdgeInsets.all(0),
                    elevation: 8,
                    color: Colors.greenAccent[700],
                    child: Center(
                      child: Text(
                        "AGREE AND CONTINE",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
