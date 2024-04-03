import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:launch_review/launch_review.dart';
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
                    onTap: (){
                      if(kIsWeb){
                        // https://play.google.com/store/apps/details?id=com.qortoba.quran.link
                        
                      }else{
                        LaunchReview.launch(
                            androidAppId: "com.qortoba.quran.link",
                            iOSAppId: "1425763263",
                          writeReview: false
                        );
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
