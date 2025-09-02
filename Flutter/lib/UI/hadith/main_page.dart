import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart';
import 'package:easy_localization/easy_localization.dart';

import 'customsearch/custom_search.dart';

class HadithHomePageClass extends StatelessWidget {
  const HadithHomePageClass({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hadith_Home_Page_Title',
          style: TextStyle(color: textColor),
        ).tr(),
        iconTheme: const IconThemeData(color: textColor),
        backgroundColor: primaryColor,
      ),
      backgroundColor: thirdColor,
      body: SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child:  Column(
              children: [
                Card(
                  shadowColor: Colors.grey.shade300,
                  color: fourthColor,
                  child: ListTile(
                    title: Text("Hadith_Home_Page_Custom_Search_Button", style: const TextStyle(fontSize:24, color: textColor),).tr(),
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HadithCustomSearchClass(),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: textColor,)
              ],
            )
        ),
      ),
    );
  }
}
