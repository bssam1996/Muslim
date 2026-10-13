import 'package:muslim/shared/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:app_launcher/app_launcher.dart';
import 'package:flutter_launch_store/flutter_launch_store.dart';
import 'package:easy_localization/easy_localization.dart';

class QuranPageClass extends StatefulWidget {
  const QuranPageClass({Key? key}) : super(key: key);

  @override
  State<QuranPageClass> createState() => _QuranPageClassState();
}

class _QuranPageClassState extends State<QuranPageClass> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Quran_Title",
          style: TextStyle(color: AppPalette.of(context).text),
        ).tr(),
        backgroundColor: AppPalette.of(context).canvas,
        iconTheme: IconThemeData(color: AppPalette.of(context).text),
      ),
      backgroundColor: AppPalette.of(context).panel,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Quran Link',
                        style: TextStyle(
                          fontSize: 24,
                          color: AppPalette.of(context).text,
                        ),
                      ),
                      trailing: Icon(
                        Icons.open_in_new,
                        color: AppPalette.of(context).text,
                      ),
                      leading: Icon(
                        Icons.book,
                        color: AppPalette.of(context).accent,
                      ),
                      onTap: () async {
                        if (kIsWeb) {
                          // https://play.google.com/store/apps/details?id=com.qortoba.quran.link
                        } else {
                          StoreLauncher.openWithStore(
                            "com.qortoba.quran.link",
                          ).catchError((e) {
                            print('ERROR> $e');
                          });
                        }
                      },
                    ),
                    Divider(color: AppPalette.of(context).text),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Quran_Page_Tip",
                    style: TextStyle(
                      fontSize: 17,
                      color: AppPalette.of(context).accent,
                    ),
                  ).tr(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
