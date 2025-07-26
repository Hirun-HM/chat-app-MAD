import 'package:chatapp/Model/country_model.dart';
import 'package:chatapp/NewScreens/country_page.dart';
import 'package:chatapp/NewScreens/otp_screen.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String countryname = "India";
  String countrycode = "+91";
  TextEditingController phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Enter Your Phone Number',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        actions: [Icon(Icons.more_vert, color: Colors.teal, size: 28)],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            Text(
              'Please enter your phone number to continue',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 5),
            Text(
              "What's my number?",
              style: TextStyle(fontSize: 16, color: Colors.cyan[700]),
            ),
            SizedBox(height: 15),
            countrycard(),
            number(),
            Expanded(child: Container()),
            InkWell(
              onTap: () {
                if (phoneController.text.length < 10) {
                  showMydilogue1();
                } else {
                  showMydilogue();
                }
              },
              child: Container(
                color: Colors.tealAccent[400],
                height: 40,
                width: 70,
                child: Center(
                  child: Text(
                    "NEXT",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget countrycard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (builder) => CountryPage(setCountryData: setcountrydata),
          ),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width / 1.5,
        padding: EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.teal, width: 1.8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                child: Center(
                  child: Text(
                    countryname,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.black, size: 28),
          ],
        ),
      ),
    );
  }

  Widget number() {
    return Container(
      width: MediaQuery.of(context).size.width / 1.5,
      height: 38,
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 70,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.teal, width: 1.8),
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: 5),
                Text(
                  "+",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 5),
                Text(
                  countrycode.replaceAll("+", ""),
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 30),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.teal, width: 1.8),
              ),
            ),
            width: MediaQuery.of(context).size.width / 1.5 - 100,
            child: TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "Phone Number",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[700]),
              ),
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void setcountrydata(CountryModel country) {
    setState(() {
      countryname = country.name ?? "India";
      countrycode = country.code ?? "+91";
    });
    Navigator.pop(context);
  }

  Future<void> showMydilogue() {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("We will verifying your phone number"),
                SizedBox(height: 10),
                Text(countrycode + " " + phoneController.text),
                SizedBox(height: 10),
                Text("is this Ok? or would you like to edit the number?"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Edit"),
            ),
            TextButton(
              onPressed: () {
                // Here you can add the logic to proceed with the phone number verification
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (builder) => OtpScreen(
                      countryCode: countrycode,
                      phoneNumber: phoneController.text,
                    ),
                  ),
                );
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> showMydilogue1() {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text("There is no Phone Number entered")],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Here you can add the logic to proceed with the phone number verification
                Navigator.pop(context);
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }
}
