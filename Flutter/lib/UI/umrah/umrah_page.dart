import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:muslim/UI/umrah/umrah_card_page.dart';
import 'package:muslim/UI/umrah/umrah_list.dart';
import 'package:muslim/shared/constants.dart';

class UmrahPageClass extends StatefulWidget {
  const UmrahPageClass({super.key});

  @override
  State<UmrahPageClass> createState() => _UmrahPageClassState();
}

class _UmrahPageClassState extends State<UmrahPageClass> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Umrah_Page_Title',
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
            itemCount: umrahItems.length,
            itemBuilder: (BuildContext context, int index) {
              return Column(
                children: [
                  Card(
                    shadowColor: Colors.grey.shade300,
                    color: fourthColor,
                    child: ListTile(
                      title: Text(umrahItems[index].title, style: const TextStyle(fontSize:24, color: textColor),).tr(),
                      onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UmrahCardPageClass(
                              title: umrahItems[index].title.tr(),
                              data: umrahItems[index].data,
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
