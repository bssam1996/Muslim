import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/qiblah/qiblah_page.dart';
import 'package:muslim/UI/quran/quran_page.dart';
import 'package:muslim/shared/constants.dart';
import 'UI/settings/settings.dart';
import 'utils/helper.dart' as helper;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/shared_preference_methods.dart' as shared_preference_methods;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    EasyLoading.showInfo("Loading settings...");
    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        _fetchAPI();
      });
    } catch (e) {
      EasyLoading.dismiss();
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Timer? refreshTimer;
  Duration refreshDuration = const Duration(seconds: 1);

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  static const headlineStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white);
  static const detailsStyle =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white);
  static const prayerStyle =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: textColor);
  static const highlightedDetailsStyle = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w500, color: highlightedColor);

  String metaData = "";

  Map<String, dynamic> jsonTimings = <String, dynamic>{};

  List<String> prayerNames = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha'
  ];
  String nextPray = 'Fajr';
  DateTime? nextPrayTime;

  Map<String, dynamic> jsonDataDate = {};

  Future<bool> _fetchAPI() async {
    dynamic jsonData;
    String? jsonEncoded = "";
    bool fetchedFromSharedPreferences = false;
    EasyLoading.show(status: 'loading...', dismissOnTap: false);
    try {
      var savedLocation = await shared_preference_methods.getStringData(
          _prefs, 'location', true);
      if (savedLocation == null) {
        EasyLoading.showError(
            "Location is unset and it is needed! please go to settings to add a location",
            duration: const Duration(seconds: 10));
        return false;
      }
      String formattedDate = helper.dateFormatter(DateTime.now());
      var sharedData = await shared_preference_methods.getStringData(
          _prefs, formattedDate, true);
      if (sharedData != null) {
        fetchedFromSharedPreferences = true;
        if (kDebugMode) {
          print("Fetching from shared-preferences");
        }
        jsonData = sharedData;
      } else {
        if (kDebugMode) {
          print("Fetching from API");
        }
        var r = await helper.fetchData(formattedDate, savedLocation, _prefs);
        jsonEncoded = r?.body;
        jsonData = jsonDecode(jsonEncoded!);
      }
      if (jsonData != null && jsonData['code'] == 200) {
        if (!fetchedFromSharedPreferences) {
          if (kDebugMode) {
            print("Setting in shared-preferences");
          }
          bool result = await shared_preference_methods.setStringData(
              _prefs, formattedDate, jsonEncoded);
          if (!result) {
            EasyLoading.showError("Couldn't save data", dismissOnTap: true);
          }
        }
        Map<String, dynamic> timings = jsonData['data']['timings'];
        int prayerIndex = 0;
        bool found = false;
        DateTime currentDateTime = DateTime.now();
        for (prayerIndex = 0; prayerIndex < prayerNames.length; prayerIndex++) {
          String name = prayerNames[prayerIndex];
          DateTime constructedDateTime =
              helper.constructDateTime(timings[name].toString());
          if (constructedDateTime.compareTo(currentDateTime) > 0) {
            found = true;
            nextPrayTime = constructedDateTime;
            break;
          }
        }
        if (found) {
          nextPray = prayerNames[prayerIndex];
        } else {
          nextPray = prayerNames[0];
          nextPrayTime =
              helper.constructDateTime(timings[prayerNames[0]].toString());
          nextPrayTime = nextPrayTime?.add(const Duration(days: 1));
        }

        //24 System check
        var exists = await shared_preference_methods.checkExistenceData(
            _prefs, '24system');
        if (exists) {
          var shared24 =
              await shared_preference_methods.getBoolData(_prefs, '24system');
          if (shared24 != null && shared24 == false) {
            // Convert to 12 system
            timings.forEach((timingName, timingValue) {
              List<String> timingWhole = timingValue.toString().split(":");
              int timingHour = int.parse(timingWhole[0]);
              int timingMinute = int.parse(timingWhole[1]);
              DateTime constructedDateTime = DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                  timingHour,
                  timingMinute,
                  DateTime.now().second);
              var newValue =
                  helper.customtimeFormatter("h:mm a", constructedDateTime);
              jsonData['data']['timings'][timingName] = newValue;
            });
          }
        } else {
          await shared_preference_methods.setBoolData(_prefs, '24system', true);
        }
        setState(() {
          jsonDataDate = jsonData['data']['date'];
          jsonTimings = jsonData['data']['timings'];
          metaData = processMetaData(jsonData['data']['meta']);
        });
        resetTimer();
        EasyLoading.dismiss();
      } else {
        EasyLoading.showError("API didn't return any data!",
            dismissOnTap: true);
        if (fetchedFromSharedPreferences) {
          shared_preference_methods.invalidateSharedData(_prefs, formattedDate);
        }
        return false;
      }
      return true;
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError("Something went wrong $e", dismissOnTap: true);
      return false;
    }
  }
  final drawerHeader = UserAccountsDrawerHeader(
    accountEmail: null,
    currentAccountPicture: CircleAvatar(
      child: CircleAvatar(
        backgroundColor: Colors.grey[100],
        child: ClipOval(
          child: Image.asset(
            'assets/icon/main.png',
            width: 512.0,
            height: 512.0,
          ),
        ),
        radius: 50.0,
      ),
      backgroundColor: thirdColor,
    ),
    accountName: const Text(gloabalAppName,style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
  );
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        return _fetchAPI();
      },
      child: Scaffold(
        backgroundColor: thirdColor,
        drawer: Drawer(
          backgroundColor: fourthColor,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              drawerHeader,
              Column(
                children: [
                  ListTile(
                    title: const Text('Qiblah Compass', style: TextStyle(color: textColor),),
                    trailing: Image.asset("assets/qiblah/compass.png",width: 24,),
                    onTap: () async{
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const QiblahClass()),
                      );
                    },
                  ),
                  const Divider(color: textColor,),
                ],
              ),
              Column(
                children: [
                  ListTile(
                    title: const Text('Quran', style: TextStyle(color: textColor),),
                    trailing: Image.asset("assets/quran/quran.png",width: 24, color: textColor,),
                    onTap: () async{
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const QuranPageClass()),
                      );
                    },
                  ),
                  const Divider(color: textColor,),
                ],
              ),
              Column(
                children: [
                  ListTile(
                    title: const Text('Settings', style: TextStyle(color: textColor)),
                    trailing: const Icon(Icons.settings, color: textColor, size: 24,),
                    onTap: () async{
                      stopTimer();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SettingsPageClass(prefs: _prefs)),
                      );
                      helper.invalidateTodayCachedData(_prefs);
                      var location = await shared_preference_methods.getStringData(
                          _prefs, 'location', true);
                      if (location != null) {
                        _fetchAPI();
                      }
                    },
                  ),
                  const Divider(color: textColor,),
                ],
              ),
            ],
          ),
        ),
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Center(
                          child: Column(
                        children: [
                          AutoSizeText(
                            jsonDataDate["gregorian"]?["month"]?["en"] ??
                                "Month",
                            style: headlineStyle.copyWith(fontSize: 20),
                          ),
                          AutoSizeText(
                            jsonDataDate["gregorian"]?["date"] ?? "gregorian",
                            style: headlineStyle.copyWith(fontSize: 20),
                          ),
                        ],
                      )),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                          child: Column(
                        children: [
                          AutoSizeText(
                            jsonDataDate["hijri"]?["month"]?["en"] ?? "Month",
                            style: headlineStyle.copyWith(fontSize: 20),
                          ),
                          AutoSizeText(
                            jsonDataDate["hijri"]?["date"] ?? "hijri",
                            style: headlineStyle.copyWith(fontSize: 20),
                          ),
                        ],
                      )),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildTimeCard(nextPrayTime != null
                        ? (helper.constructTimeLeftSplitted(
                            nextPrayTime!.difference(DateTime.now()), "hour"))
                        : "-"),
                    buildTimeCard(nextPrayTime != null
                        ? (helper.constructTimeLeftSplitted(
                            nextPrayTime!.difference(DateTime.now()), "minute"))
                        : "-"),
                    buildTimeCard(nextPrayTime != null
                        ? (helper.constructTimeLeftSplitted(
                            nextPrayTime!.difference(DateTime.now()), "second"))
                        : "-"),
                  ],
                ),
                const Divider(
                  height: 20,
                  thickness: 5,
                  color: dividerColor,
                ),
                RefreshIndicator(
                    child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: prayerNames.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Column(
                            children: [
                              detailsRow(prayerNames[index],
                                  jsonTimings[prayerNames[index]] ?? "-"),
                            ],
                          );
                        }),
                    onRefresh: () {
                      return _fetchAPI();
                    }),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(
                      metaData,
                      style: detailsStyle.copyWith(fontSize: 18),
                    ),
                    const Divider(),
                    Text(
                      declaration,
                      style: highlightedDetailsStyle.copyWith(fontSize: 12),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _fetchAPI,
          tooltip: 'Fetch',
          child: const Icon(Icons.get_app),
        ),
      ),
    );
  }

  Widget detailsRow(String headText, String detailsText) {
    return SizedBox(
      height: 50,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: const BorderSide(
            color: boxesBorderColor,
          ),
        ),
        shadowColor: Colors.blueGrey,
        color: fourthColor,
        elevation: 15,
        margin: const EdgeInsets.all(5),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.3,
                child: Center(
                  child: Text("$headText:",
                      style: nextPray == headText
                          ? highlightedDetailsStyle
                          : prayerStyle),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: SizedBox(
                width: MediaQuery.of(context).size.width / 2 * 3,
                child: Center(
                  child: Text(detailsText,
                      style: nextPray == headText
                          ? highlightedDetailsStyle
                          : prayerStyle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void startTimer() {
    refreshTimer = Timer.periodic(refreshDuration, (_) {
      if (nextPrayTime != null) {
        if (nextPrayTime!.isBefore(DateTime.now())) {
          setState(() async {
            await _fetchAPI();
          });
        } else {
          setState(() {});
        }
      }
    });
  }

  // Step 4
  void stopTimer() {
    if (refreshTimer != null) {
      setState(() => refreshTimer!.cancel());
    }
  }

  // Step 5
  void resetTimer() {
    stopTimer();
    startTimer();
  }

  Widget buildTimeCard(String time) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: boxesBorderColor,
            ),
            color: fourthColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            time,
            style: highlightedDetailsStyle.copyWith(fontSize: 25),
          ),
        )
      ],
    );
  }

  String processMetaData(meta) {
    String metaResponse = "Timezone: ${meta["timezone"]}\n";
    metaResponse = "${metaResponse}Longitude: ${meta["longitude"]}\n";
    metaResponse = "${metaResponse}Latitude: ${meta["latitude"]}\n";
    metaResponse = "${metaResponse}Method: ${meta["method"]["name"]}\n";
    metaResponse = "${metaResponse}School: ${meta["school"]}";
    return metaResponse;
  }
}
