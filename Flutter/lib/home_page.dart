import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io' show Platform;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:muslim/UI/month/months_page.dart';
import 'package:muslim/UI/contact/contact.dart';
import 'package:muslim/UI/qiblah/qiblah_page.dart';
import 'package:muslim/UI/quran/quran_page.dart';
import 'package:muslim/shared/constants.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'UI/settings/settings.dart';
import 'utils/helper.dart' as helper;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/shared_preference_methods.dart' as shared_preference_methods;
import 'package:home_widget/home_widget.dart';
import 'package:easy_localization/easy_localization.dart' as easy_Localization;
import 'package:seeip_client/seeip_client.dart';

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
    if (Platform.isAndroid) {
      HomeWidget.setAppGroupId(HOME_WIDGET_GROUP_ID);
    }
    EasyLoading.showInfo("Loading settings...");
    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
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
  // static const detailsStyle =
  //     TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white);
  static const prayerStyle =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: textColor);
  static const highlightedDetailsStyle = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w500, color: highlightedColor);

  Widget metaData = DataTable(
      columns: [DataColumn(label: Text("")), DataColumn(label: Text(""))],
      rows: []);

  List<Map<String, dynamic>> jsonTimings = List<Map<String, dynamic>>.filled(7, <String,dynamic>{});

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

  List<Map<String, dynamic>> jsonDataDate = List<Map<String, dynamic>>.filled(7, {});

  Future<bool> _fetchAPI() async {
    EasyLoading.show(status: 'loading...', dismissOnTap: false);
    try {
      var savedLocation = await shared_preference_methods.getStringData(
          _prefs, 'location', true);
      if (savedLocation == null) {
        try {
          var seeip = SeeipClient();
          var ip = await seeip.getIP();
          var geoLocation = await seeip.getGeoIP(ip.ip);
          Map<String, dynamic> location = {
            "location":
                "${geoLocation.city}, ${geoLocation.region}, ${geoLocation.country}",
            "type": "address"
          };
          bool result = await shared_preference_methods.setStringData(
              _prefs, "location", json.encode(location));
          if (!result) {
            EasyLoading.showError("Location_Missing_Error".tr(),
                duration: const Duration(seconds: 10), dismissOnTap: true);
            return false;
          }
          savedLocation = location;
        } catch (e) {
          EasyLoading.showError("Location_Missing_Error".tr(),
              duration: const Duration(seconds: 10), dismissOnTap: true);
          return false;
        }
      }
      int numberOfDays = 7;

      for (int dayNumber = 0; dayNumber < numberOfDays; dayNumber++){
        dynamic jsonData;
        String? jsonEncoded = "";
        bool fetchedFromSharedPreferences = false;
        // Format today's date and next 6 days
        DateTime d = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + dayNumber);
        String formattedDate = helper.dateFormatter(d);
        // Construct API url from helpers
        String? sharedKey = await helper.constructAPIParameters("", formattedDate, savedLocation, _prefs);
        if (sharedKey == null){
          EasyLoading.dismiss();
          EasyLoading.showError("Something went wrong: Couldn't construct shared key", dismissOnTap: true);
          return false;
        }
        var sharedData = await shared_preference_methods.getStringData(
            _prefs, sharedKey, true);
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
          var r =
          await helper.fetchData("", formattedDate, savedLocation, _prefs);
          jsonEncoded = r?.body;
          jsonData = jsonDecode(jsonEncoded!);
        }
        if (jsonData != null && jsonData['code'] == 200) {
          if (!fetchedFromSharedPreferences) {
            if (kDebugMode) {
              print("Setting in shared-preferences");
            }
            bool result = await shared_preference_methods.setStringData(
                _prefs, sharedKey, jsonEncoded);
            if (!result) {
              EasyLoading.showError("Couldn't save data", dismissOnTap: true);
            }
          }
          Map<String, dynamic> timings = jsonData['data']['timings'];

          // Calculate next prayer times for next praying
          if(dayNumber == 0){
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
            // Only call setstate once
            jsonDataDate[dayNumber] = jsonData['data']['date'];
            jsonTimings[dayNumber] = jsonData['data']['timings'];
            metaData = processMetaData(jsonData['data']['meta']);
            if (Platform.isAndroid && dayNumber == 0){
              updateHomePage(jsonTimings[0], jsonDataDate[0]);
            }
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
      backgroundColor: thirdColor,
      child: CircleAvatar(
        backgroundColor: Colors.grey[100],
        radius: 50.0,
        child: ClipOval(
          child: Image.asset(
            'assets/icon/main.png',
            width: 512.0,
            height: 512.0,
          ),
        ),
      ),
    ),
    accountName: const Text(
      gloabalAppName,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    decoration: const BoxDecoration(color: primaryColor),
    arrowColor: textColor,
  );

  final controller = PageController(viewportFraction: 0.8, keepPage: true);
  final pages = List.generate(7, (index) => Container());

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
                    title: const Text(
                      'Home_Panel_Qiblah',
                      style: TextStyle(color: textColor),
                    ).tr(),
                    trailing: Image.asset(
                      "assets/qiblah/compass.png",
                      width: 24,
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const QiblahClass()),
                      );
                    },
                  ),
                  const Divider(
                    color: textColor,
                  ),
                ],
              ),
              Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Home_Panel_Quran',
                      style: TextStyle(color: textColor),
                    ).tr(),
                    trailing: Image.asset(
                      "assets/quran/quran.png",
                      width: 24,
                      color: textColor,
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const QuranPageClass()),
                      );
                    },
                  ),
                  const Divider(
                    color: textColor,
                  ),
                ],
              ),
              Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Home_Panel_Prayer_Calendar',
                      style: TextStyle(color: textColor),
                    ).tr(),
                    trailing: Image.asset(
                      "assets/prayercalender/prayercalender.png",
                      width: 24,
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const MonthsPageClass()),
                      );
                    },
                  ),
                  const Divider(
                    color: textColor,
                  ),
                ],
              ),
              Column(
                children: [
                  ListTile(
                    title: const Text('Home_Panel_Settings',
                            style: TextStyle(color: textColor))
                        .tr(),
                    trailing: const Icon(
                      Icons.settings,
                      color: textColor,
                      size: 24,
                    ),
                    onTap: () async {
                      stopTimer();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                SettingsPageClass(prefs: _prefs)),
                      );
                      helper.invalidateTodayCachedData(_prefs);
                      var location = await shared_preference_methods
                          .getStringData(_prefs, 'location', true);
                      if (location != null) {
                        _fetchAPI();
                      }
                    },
                  ),
                  const Divider(
                    color: textColor,
                  ),
                  ListTile(
                    title: const Text('Home_Panel_Contact',
                        style: TextStyle(color: textColor))
                        .tr(),
                    trailing: const Icon(
                      Icons.contact_support,
                      color: textColor,
                      size: 24,
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ContactPageClass()),
                      );
                    },
                  ),
                  const Divider(
                    color: textColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: Text(
            widget.title.tr(),
            style: const TextStyle(color: textColor),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: textColor),
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 455,
                  child: PageView.builder(
                    controller: controller,
                    itemCount: 7,
                    itemBuilder: (_, index) {
                      return prayerTimingPage(index);
                    },
                  ),
                ),
                // prayerTimingPage(0),
                SmoothPageIndicator(
                  controller: controller,
                  count: 7,
                  effect: const JumpingDotEffect(
                    dotHeight: 16,
                    dotWidth: 16,
                    activeDotColor: highlightedColor
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 20,
                            color: fourthColor,
                            shadowColor: thirdColor,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: metaData,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Text(
                      "Home_Page_Declaration".tr(),
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
          tooltip: 'Reload'.tr(),
          child: const Icon(
            Icons.get_app,
            color: textColor,
          ),
          backgroundColor: primaryColor,
        ),
      ),
    );
  }

  Widget prayerTimingPage(int daynumber) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            thirdColor,
            fourthColor,
            thirdColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor,
            spreadRadius: 1,
            blurRadius: 10,// changes position of shadow
          ),
        ],
      ),
      child: Card(

        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
              children: <Widget>[
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                    children: [
                      AutoSizeText(
                        (jsonDataDate[daynumber]["gregorian"]?["month"]?["en"] ?? "Month")
                            .toString()
                            .tr(),
                        style: headlineStyle.copyWith(fontSize: 20),
                      ),
                      AutoSizeText(
                        jsonDataDate[daynumber]["gregorian"]?["date"] ?? "gregorian",
                        style: headlineStyle.copyWith(fontSize: 20),
                      ),
                    ],
                  )),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                    children: [
                      AutoSizeText(
                        (jsonDataDate[daynumber]["hijri"]?["month"]?["en"] ?? "Month")
                            .toString()
                            .tr(),
                        style: headlineStyle.copyWith(fontSize: 20),
                      ),
                      AutoSizeText(
                        jsonDataDate[daynumber]["hijri"]?["date"] ?? "hijri",
                        style: headlineStyle.copyWith(fontSize: 20),
                      ),
                    ],
                  )),
                ),
              ],
            ),
            Visibility(
              visible: daynumber==0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textDirection: TextDirection.ltr,
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
                              jsonTimings[daynumber][prayerNames[index]] ?? "-", daynumber),
                        ],
                      );
                    }),
                onRefresh: () {
                  return _fetchAPI();
                }),
          ]),
        ),
      ),
    );
  }

  Widget detailsRow(String headText, String detailsText, int dayNumber) {
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
                  child: Text("${headText.tr()}:",
                      style: nextPray == headText
                          ? (dayNumber==0)?highlightedDetailsStyle:prayerStyle
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
                      textDirection: TextDirection.ltr,
                      style: nextPray == headText
                          ? (dayNumber==0)?highlightedDetailsStyle:prayerStyle
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

  Widget processMetaData(meta) {
    List<DataRow> datarows = [];
    datarows.add(buildMetaRow(
        "Home_Page_Meta_Timezone".tr(), meta["timezone"]?.toString() ?? ""));
    datarows.add(buildMetaRow(
        "Home_Page_Meta_Longitude".tr(), meta["longitude"]?.toString() ?? ""));
    datarows.add(buildMetaRow(
        "Home_Page_Meta_Latitude".tr(), meta["latitude"]?.toString() ?? ""));
    datarows.add(buildMetaRow("Home_Page_Meta_Method".tr(),
        meta["method"]["name"]?.toString() ?? ""));
    datarows.add(buildMetaRow(
        "Home_Page_Meta_School".tr(), meta["school"]?.toString() ?? ""));
    List<DataColumn> dataColumns = [];
    dataColumns.add(buildMetaColumn("Home_Page_Meta_Type".tr()));
    dataColumns.add(buildMetaColumn("Home_Page_Meta_Value".tr()));
    DataTable dataTable = DataTable(
      columns: dataColumns,
      rows: datarows,
      headingRowHeight: 22,
      dataRowMinHeight: 22,
      dataRowMaxHeight: 22,
    );
    return dataTable;
  }

  DataRow buildMetaRow(String label, String value) {
    DataRow dataRow = DataRow(cells: [
      DataCell(Container(
        alignment: Alignment.center,
        child: FittedBox(
          child: Text(
            label,
            style: const TextStyle(color: textColor),
          ),
        ),
      )),
      DataCell(
          Container(
            alignment: Alignment.center,
            child: FittedBox(
              child: Text(
                value,
                style: const TextStyle(color: textColor),
                textDirection: TextDirection.ltr,
              ),
            ),
          ), onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        EasyLoading.showSuccess("Copied".tr());
      }),
    ]);
    return dataRow;
  }

  DataColumn buildMetaColumn(String text) {
    return DataColumn(
        label: Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    ));
  }

  void updateHomePage(
      Map<String, dynamic> jsonTimings, Map<String, dynamic> jsonData) async {
    Future.wait<bool?>([
      HomeWidget.saveWidgetData<String>(
          "fajr_text", jsonTimings["Fajr"].toString()),
      HomeWidget.saveWidgetData<String>("fajr_label", "Fajr".tr()),
      HomeWidget.saveWidgetData<String>(
          "sunrise_text", jsonTimings["Sunrise"].toString()),
      HomeWidget.saveWidgetData<String>("sunrise_label", "Sunrise".tr()),
      HomeWidget.saveWidgetData<String>(
          "dhuhr_text", jsonTimings["Dhuhr"].toString()),
      HomeWidget.saveWidgetData<String>("dhuhr_label", "Dhuhr".tr()),
      HomeWidget.saveWidgetData<String>(
          "asr_text", jsonTimings["Asr"].toString()),
      HomeWidget.saveWidgetData<String>("asr_label", "Asr".tr()),
      HomeWidget.saveWidgetData<String>(
          "maghrib_text", jsonTimings["Maghrib"].toString()),
      HomeWidget.saveWidgetData<String>("maghrib_label", "Maghrib".tr()),
      HomeWidget.saveWidgetData<String>(
          "isha_text", jsonTimings["Isha"].toString()),
      HomeWidget.saveWidgetData<String>("isha_label", "Isha".tr()),
      HomeWidget.saveWidgetData<String>(
          "gregorianDate_text", jsonData["gregorian"]?["date"] ?? "Month"),
      HomeWidget.saveWidgetData<String>(
          "hijriDate_text", jsonData["hijri"]?["date"] ?? "Month"),
    ]).then((value) {
      HomeWidget.updateWidget(
        name: "HomeAppWidget",
        androidName: "HomeAppWidget",
      );
      HomeWidget.updateWidget(
        name: "HomeAppWidgetWide",
        androidName: "HomeAppWidgetWide",
      );
    });

    // HomeWidget.renderFlutterWidget(
    //   const Icon(
    //     Icons.flutter_dash,
    //     size: 200,
    //   ),
    //   logicalSize: const Size(200, 200),
    //   key: 'dashIcon',
    // );
  }
}
