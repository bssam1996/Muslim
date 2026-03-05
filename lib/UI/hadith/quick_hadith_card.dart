import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../../shared/constants.dart' as constants;

class QuickHadithCardPageClass extends StatefulWidget {
  final String hadith;
  const QuickHadithCardPageClass({Key? key, required this.hadith})
      : super(key: key);

  @override
  State<QuickHadithCardPageClass> createState() =>
      _QuickHadithCardPageClassState();
}

class _QuickHadithCardPageClassState extends State<QuickHadithCardPageClass> {
  double fontSize = 20;
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      fontSize = 32;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit:BoxFit.fitHeight,
      child: Center(
        child: Card(
          color: constants.fourthColor,
          elevation: 8.0, // Shadow depth for the card
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // Rounded corners
          ),
          margin: const EdgeInsets.only(bottom: 8.0), // Space between cards
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 10,
                child: SelectableText(
                  widget.hadith,
                  style: TextStyle(fontSize: fontSize, fontFamily: 'Uthman', overflow: TextOverflow.ellipsis, color: constants.textColor),
                  textAlign: TextAlign.center,
                  textDirection: ui.TextDirection.rtl,
                  // maxLines: 50,
                ),
              ),
              // child: SizedBox(
              //   width: MediaQuery.of(context).size.width - 10,
              //   child: Text(
              //     widget.hadith,
              //     style: TextStyle(fontSize: fontSize, fontFamily: 'Uthman'),
              //     // textAlign: TextAlign.center,
              //     textDirection: ui.TextDirection.rtl,
              //     softWrap: true,
              //     maxLines: 50,
              //     overflow: TextOverflow.ellipsis,
              //   ),
              // ),
            ),
          ),
        ),
      ),
    );
  }
}
