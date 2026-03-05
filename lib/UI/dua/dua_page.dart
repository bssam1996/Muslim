import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:muslim/UI/dua/dua_card_page.dart';
import 'package:muslim/UI/dua/dua_list.dart';
import 'package:muslim/shared/constants.dart';

class DuaPageClass extends StatefulWidget {
  const DuaPageClass({super.key});

  @override
  State<DuaPageClass> createState() => _DuaPageClassState();
}

class _DuaPageClassState extends State<DuaPageClass> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dua_Page_Title',
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
            itemCount: duaItems.length,
            itemBuilder: (BuildContext context, int index) {
              return Column(
                children: [
                  Card(
                    shadowColor: Colors.grey.shade300,
                    color: fourthColor,
                    child: ListTile(
                      title: Text(duaItems[index].title, style: const TextStyle(fontSize:24, color: textColor),).tr(),
                      onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DuaCardPageClass(
                              title: duaItems[index].title.tr(),
                              data: duaItems[index].data,
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
