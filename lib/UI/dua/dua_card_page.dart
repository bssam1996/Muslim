import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart';

class DuaCardPageClass extends StatefulWidget {
  final String title;
  final String data;
  const DuaCardPageClass({Key? key, required this.title, required this.data})
      : super(key: key);

  @override
  State<DuaCardPageClass> createState() => _DuaCardPageClassState();
}

class _DuaCardPageClassState extends State<DuaCardPageClass> {
  double fontSize = 16;
  @override
  void initState() {
    super.initState();
    if(kIsWeb){
      fontSize = 28;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: textColor),
        actions: [
          IconButton(onPressed: (){
            setState(() {
              fontSize += 1;
            });
          }, icon: const Icon(Icons.add, color: Colors.white54,), color: Colors.white54),
          IconButton(onPressed: (){
            setState(() {
              fontSize -= 1;
            });
          }, icon: const Icon(Icons.remove, color: Colors.white,), color: Colors.white54)
        ],
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
                child: SelectableText(
                  widget.data,
                  style: TextStyle(fontSize: fontSize, fontFamily: 'Uthman'),
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
