import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../utils/hadith_utils.dart';
class FindHadithCardClass extends StatelessWidget {
  final HadithCustomSearchObject hadith;
  const FindHadithCardClass({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    double fontSize = 20;
    if (kIsWeb) {
      fontSize = 32;
    }
    return FittedBox(
      fit:BoxFit.fitHeight,
      child: Card(
        elevation: 8.0, // Shadow depth for the card
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0), // Rounded corners
        ),
        margin: const EdgeInsets.only(bottom: 8.0), // Space between cards
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 10,
            child: Column(
              crossAxisAlignment: Directionality.of(context) == ui.TextDirection.rtl ? CrossAxisAlignment.start:CrossAxisAlignment.end,
              children: [
                Text(
                  hadith.hadith,
                  style: TextStyle(fontSize: fontSize, fontFamily: 'Uthman', overflow: TextOverflow.visible),
                  textDirection: ui.TextDirection.rtl,
                  // maxLines: 50,
                ),
                Divider(),
                Text(
                  "الراوي: " + hadith.narrator,
                  style: TextStyle(fontSize: fontSize, fontFamily: 'Uthman', overflow: TextOverflow.visible),
                  textDirection: ui.TextDirection.rtl,
                  // maxLines: 50,
                ),
                Divider(),
                Text(
                  "المحدث: " + hadith.muhaddith,
                  style: TextStyle(fontSize: fontSize, fontFamily: 'Uthman', overflow: TextOverflow.visible),
                  textDirection: ui.TextDirection.rtl,
                  // maxLines: 50,
                ),
                Divider(),
                Text(
                  "المصدر: " + hadith.source,
                  style: TextStyle(fontSize: fontSize, fontFamily: 'Uthman', overflow: TextOverflow.visible),
                  textDirection: ui.TextDirection.rtl,
                  // maxLines: 50,
                ),
                Divider(),
                Text(
                  "صفحه: " + hadith.page,
                  style: TextStyle(fontSize: fontSize, fontFamily: 'Uthman', overflow: TextOverflow.visible),
                  textDirection: ui.TextDirection.rtl,
                  // maxLines: 50,
                ),
                Divider(),
                Text(
                  "حكم المحدث: " + hadith.ruling,
                  style: TextStyle(fontSize: fontSize, fontFamily: 'Uthman', overflow: TextOverflow.visible),
                  textDirection: ui.TextDirection.rtl,
                  // maxLines: 50,
                ),
                Divider(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
