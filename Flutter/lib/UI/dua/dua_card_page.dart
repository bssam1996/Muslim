import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart';

class DuaCardPageClass extends StatelessWidget {
  final String title;
  final String data;
  const DuaCardPageClass({Key? key, required this.title, required this.data})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: primaryColor,
      ),
      backgroundColor: thirdColor,
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(
                16.0), // Outer padding for the entire card area
            child: Card(
              elevation: 8.0, // Shadow depth for the card
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0), // Rounded corners
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(16.0), // Inner padding for the text
                child: Text(
                  data,
                  style: const TextStyle(fontSize: 16.0, fontFamily: 'Uthman'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
