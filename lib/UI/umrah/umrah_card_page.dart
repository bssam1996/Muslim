import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:muslim/shared/constants.dart';

class UmrahCardPageClass extends StatefulWidget {
  final String title;
  final String data;
  const UmrahCardPageClass({Key? key, required this.title, required this.data})
      : super(key: key);

  @override
  State<UmrahCardPageClass> createState() => _UmrahCardPageClassState();
}

class _UmrahCardPageClassState extends State<UmrahCardPageClass> {
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
      body: Padding(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Markdown(
                      data: widget.data,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        textAlign: WrapAlignment.start,
                        p: TextStyle(fontSize: fontSize, fontFamily: 'Uthman'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
