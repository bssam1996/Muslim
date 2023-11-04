import 'package:flutter/material.dart';
import 'package:launch_review/launch_review.dart';
import 'package:muslim/shared/constants.dart';
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
        title: const Text("Quran"),
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
                      LaunchReview.launch(
                          androidAppId: "com.qortoba.quran.link",
                          iOSAppId: "1425763263",
                        writeReview: false
                      );
                    },
                  ),
                  const Divider(color: textColor,)
                ],
              ),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Currently, quran is not implemented in Muslim app's core. You can find list of recommended apps above for Quran",style: TextStyle(fontSize:17, color: highlightedColor),),
              )
            ],
          ),
        ),
      )
    );
  }
}
