import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/azkar/azkar_items.dart';
import 'package:muslim/home_page.dart';
import 'package:muslim/shared/constants.dart';
import 'azkar_list.dart';
import 'dart:ui' as ui;

class AzkarCardPageClass extends StatefulWidget {
  final String keyname;
  const AzkarCardPageClass({Key? key, required this.keyname})
      : super(key: key);

  @override
  State<AzkarCardPageClass> createState() => _AzkarCardPageClassState();
}

class _AzkarCardPageClassState extends State<AzkarCardPageClass> {
  double fontSize = 16;
  late List<AzkarItem> azkaritems;
  @override
  void initState() {
    super.initState();
    if(kIsWeb){
      fontSize = 28;
    }
    azkaritems = AzkarCategories[widget.keyname]!;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.keyname).tr(),
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
            child: Column(
              children: azkaritems.map((azkarItem) {
                return Card(
                  elevation: 8.0, // Shadow depth for the card
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0), // Rounded corners
                  ),
                  margin: const EdgeInsets.only(bottom: 16.0), // Space between cards
                  child: Padding(
                    padding: const EdgeInsets.all(16.0), // Inner padding for the text
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: SelectableText(
                            azkarItem.data,
                            style: TextStyle(fontSize: fontSize, fontFamily: 'Uthman'),
                            textAlign: TextAlign.center,
                            textDirection: ui.TextDirection.rtl,
                          ),
                        ),
                        const SizedBox(height: 8.0), // Space between sections
                        Visibility(
                          visible: azkarItem.description!="",
                          child: Text(
                            "${"Azkar_Card_Description".tr()}: ${azkarItem.description}",
                            style: TextStyle(fontSize: fontSize * 0.6),
                          ),
                        ),
                        Text(
                          "${"Azkar_Card_Repeat".tr()}: ${azkarItem.count}",
                          style: TextStyle(fontSize: fontSize * 0.6),
                          textDirection: ui.TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
