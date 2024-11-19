import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:muslim/UI/azkar/azkar_card_page.dart';
import 'package:muslim/UI/azkar/azkar_list.dart';
import 'package:muslim/shared/constants.dart';

class AzkarPageClass extends StatefulWidget {
  const AzkarPageClass({super.key});

  @override
  State<AzkarPageClass> createState() => _AzkarPageClassState();
}

class _AzkarPageClassState extends State<AzkarPageClass> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Azkar_Page_Title',
          style: TextStyle(color: textColor),
        ).tr(),
        iconTheme: const IconThemeData(color: textColor),
        backgroundColor: primaryColor,
      ),
        backgroundColor: thirdColor,
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: AzkarCategories.length,
            itemBuilder: (BuildContext context, int index) {
              String key = AzkarCategories.keys.elementAt(index);
              return Column(
                children: [
                  Card(
                    shadowColor: Colors.grey.shade300,
                    color: fourthColor,
                    child: ListTile(
                      title: Text(key, style: const TextStyle(fontSize:24, color: textColor),).tr(),
                      onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AzkarCardPageClass(
                              keyname: key
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(color: textColor,)
                ],
              );
            },
          ),
        )
    );
  }
}
