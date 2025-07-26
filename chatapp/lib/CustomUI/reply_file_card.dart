import 'dart:io';

import 'package:flutter/material.dart';

class ReplyFileCard extends StatelessWidget {
  const ReplyFileCard({super.key, this.path, this.message, this.time});
  final String? path;
  final String? message;
  final String? time;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
        child: Container(
          height: MediaQuery.of(context).size.height / 2.3,
          width: MediaQuery.of(context).size.width / 1.8,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: 
                Image.network("http://192.168.56.1/uploads/$path",
                fit: BoxFit.fitHeight)),
                (message != null && message!.length > 0)
                    ? Container(
                        height: 40,
                        padding: EdgeInsets.only(left: 15, top: 8),

                        child: Text(
                          message ?? '',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : Container(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
