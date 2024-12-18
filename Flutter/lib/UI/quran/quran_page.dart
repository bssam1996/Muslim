import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:app_launcher/app_launcher.dart';
import 'package:flutter_launch_store/flutter_launch_store.dart';
import 'package:muslim/shared/constants.dart';
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
        title: const Text("Quran_Title", style: TextStyle(color: textColor),).tr(),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: textColor),
      ),
      backgroundColor: thirdColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              Column(
                children: [
                  ListTile(
                    title: const Text('Quran Link', style: TextStyle(fontSize:24, color: textColor),),
                    onTap: () async{
                      if(kIsWeb){
                        // https://play.google.com/store/apps/details?id=com.qortoba.quran.link
                        
                      }else{
                        StoreLauncher.openWithStore("com.qortoba.quran.link").catchError((e) {
                          print('ERROR> $e');
                        });
                      }
                    },
                  ),
                  const Divider(color: textColor,)
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Text("Quran_Page_Tip",style: TextStyle(fontSize:17, color: highlightedColor),).tr(),
              )
            ],
          ),
        ),
      )
    );
  }
}
