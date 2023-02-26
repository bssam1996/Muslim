import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'UI/settings/settings.dart';
import 'utils/helper.dart' as helper;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/sharedpreference_methods.dart' as shared_preference_methods;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  TextEditingController locationController = TextEditingController();
  static const headlineStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold);
  static const detailsStyle =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w500);
  static const highlightedDetailsStyle =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.green);

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

  String jsonDataDate = "Date";

  Future<bool> _fetchAPI() async {
    bool saveLocation = false;
    // Check location
    if (locationController.text.isEmpty) {
      EasyLoading.showError("Location is needed!");
      return false;
    } else {
      // Compare input with saved location
      try {
        var savedLocation = await shared_preference_methods.getStringData(
            _prefs, 'location', true);
        if (savedLocation == null ||
            savedLocation['location'] != locationController.text) {
          saveLocation = true;
        }
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
        EasyLoading.showError("Something went wrong while checking saved Data",
            dismissOnTap: true);
      }
    }
    var jsonData;
    String? jsonEncoded = "";
    bool fitchedFromSharedPreferences = false;
    EasyLoading.show(status: 'loading...', dismissOnTap: false);
    try {
      String formattedDate = helper.dateFormatter(DateTime.now());
      var sharedData = await shared_preference_methods.getStringData(
          _prefs, formattedDate, true);
      if (sharedData != null && saveLocation == false) {
        fitchedFromSharedPreferences = true;
        if (kDebugMode) {
          print("Fetching from shared-preferences");
        }
        jsonData = sharedData;
      } else {
        if (kDebugMode) {
          print("Fetching from API");
        }
        var r = await helper.fetchData(formattedDate, locationController.text);
        jsonEncoded = r?.body;
        jsonData = jsonDecode(jsonEncoded!);
      }
      if (jsonData != null && jsonData['code'] == 200) {
        if (!fitchedFromSharedPreferences) {
          if (kDebugMode) {
            print("Setting in shared-preferences");
          }
          bool result = await shared_preference_methods.setStringData(
              _prefs, formattedDate, jsonEncoded);
          if (!result) {
            EasyLoading.showError("Couldn't save data", dismissOnTap: true);
          }
        }
        if (saveLocation) {
          if (kDebugMode) {
            print("Saving Location...");
          }
          Map<String, dynamic> location = {
            "location": locationController.text,
            "type": "address"
          };
          bool result = await shared_preference_methods.setStringData(
              _prefs, "location", json.encode(location));
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
          List<String> timingWhole = timings[name].toString().split(":");
          int timingHour = int.parse(timingWhole[0]);
          int timingMinute = int.parse(timingWhole[1]);
          DateTime constructedDateTime = DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
              timingHour,
              timingMinute,
              DateTime.now().second);
          if (constructedDateTime.compareTo(currentDateTime) > 0) {
            found = true;
            break;
          }
        }
        if (found) {
          nextPray = prayerNames[prayerIndex];
        } else {
          nextPray = prayerNames[0];
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
          jsonDataDate = jsonData['data']['date']['readable'];
          jsonTimings = jsonData['data']['timings'];
        });
        EasyLoading.dismiss();
      } else {
        EasyLoading.showError("API didn't return any data!",
            dismissOnTap: true);
        if (fitchedFromSharedPreferences) {
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

  @override
  void initState() {
    super.initState();
    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        var location = await shared_preference_methods.getStringData(
            _prefs, 'location', true);
        if (location != null) {
          setState(() {
            locationController.text = location['location'];
          });
          _fetchAPI();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        return _fetchAPI();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
          actions: [
            IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SettingsPageClass(prefs: _prefs)),
                  );
                  _fetchAPI();
                },
                icon: const Icon(
                  Icons.settings,
                  color: Colors.white,
                ))
          ],
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                TextFormField(
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      filled: true,
                      hintText: "What is your location",
                      labelText: "Location..."),
                  style: detailsStyle,
                  controller: locationController,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () {
                    _fetchAPI();
                  },
                ),
                const Divider(),
                Text(
                  jsonDataDate,
                  style: headlineStyle,
                ),
                const Divider(
                  height: 20,
                  thickness: 5,
                  color: Colors.grey,
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
                              const Divider(),
                            ],
                          );
                        }),
                    onRefresh: () {
                      return _fetchAPI();
                    })
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
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Center(
              child: Text("$headText:",
                  style: nextPray == headText
                      ? highlightedDetailsStyle
                      : detailsStyle),
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
                      : detailsStyle),
            ),
          ),
        ),
      ],
    );
  }
}
