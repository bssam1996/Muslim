import 'package:muslim/shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'customsearch/custom_search.dart';

class HadithHomePageClass extends StatelessWidget {
  const HadithHomePageClass({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hadith_Home_Page_Title',
          style: TextStyle(color: AppPalette.of(context).text),
        ).tr(),
        iconTheme: IconThemeData(color: AppPalette.of(context).text),
        backgroundColor: AppPalette.of(context).canvas,
      ),
      backgroundColor: AppPalette.of(context).panel,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Card(
                  shadowColor: Colors.grey.shade300,
                  color: AppPalette.of(context).panel,
                  child: ListTile(
                    title: Text(
                      "Hadith_Home_Page_Custom_Search_Button",
                      style: TextStyle(
                        fontSize: 24,
                        color: AppPalette.of(context).text,
                      ),
                    ).tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HadithCustomSearchClass(),
                        ),
                      );
                    },
                  ),
                ),
                Divider(color: AppPalette.of(context).text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
