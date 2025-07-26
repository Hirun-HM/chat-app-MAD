import 'package:flutter/material.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          CallCard("Dev Stack", "July,18:25 PM", Icons.call_made, Colors.green),
          CallCard("John Doe", "Sep,18:25 PM", Icons.call_missed, Colors.red),
        ],
      ),
    );
  }

  Widget CallCard(String name, String time, IconData icon, Color iconColor) {
    return Card(
      margin: EdgeInsets.only(bottom: 0.5),
      child: ListTile(
        leading: CircleAvatar(radius: 30),
        title: Text(
          name,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Icon(icon, color: iconColor),
            SizedBox(width: 5),
            Text(time, style: TextStyle(color: Colors.grey)),
          ],
        ),
        trailing: Icon(Icons.call, color: Colors.green),
      ),
    );
  }
}
