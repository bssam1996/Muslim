import 'dart:async';
import 'dart:core';
import 'dart:io' show Platform;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muslim/UI/azkar/azkar_page.dart';
import 'package:muslim/UI/dua/dua_page.dart';
import 'package:muslim/UI/hadith/main_page.dart';
import 'package:muslim/UI/month/months_page.dart';
import 'package:muslim/UI/contact/contact.dart';
import 'package:muslim/UI/qiblah/qiblah_page.dart';
import 'package:muslim/UI/quran/quran_page.dart';
import 'package:muslim/shared/constants.dart';
import 'package:muslim/utils/api_utils.dart' as api_utils;
import 'package:muslim/utils/hadith_utils.dart';
import 'package:muslim/utils/share_utils.dart' as share_utils;
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'UI/hadith/quick_hadith_card.dart';
import 'UI/settings/settings.dart';
import 'utils/helper.dart' as helper;
import 'utils/homewidget_utils.dart' as homewidget_utils;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/shared_preference_methods.dart' as shared_preference_methods;
import 'package:home_widget/home_widget.dart';
import 'package:easy_localization/easy_localization.dart' as easy_localization;
import 'package:upgrader/upgrader.dart';
import 'package:muslim/shared/rainbow_button.dart';

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
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        HomeWidget.setAppGroupId(HOME_WIDGET_GROUP_ID);
      }
    }
    EasyLoading.showInfo("Loading settings...");
    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        FetchAPI().then((value) async {
          if (value == false) {
            stopTimer();
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => SettingsPageClass(prefs: _prefs)),
            );
            var location = await shared_preference_methods.getStringData(
                _prefs, 'location', true);
            if (location != null) {
              FetchAPI();
            } else {
              EasyLoading.showError("Location_Missing_Error".tr(),
                  duration: const Duration(seconds: 10), dismissOnTap: true);
            }
          }
        });
      });
      getRandomHadith().then((value){
        if (!mounted) return;
        setState(() {
          hadithOfTheDay = value;
        });
      });
    } catch (e) {
      EasyLoading.dismiss();
      if (kDebugMode) {
        print(e);
      }
    }
  }

  String savedLocationAddress = "-";
  int _selectedDayIndex = 0;
  Timer? refreshTimer;
  Duration refreshDuration = const Duration(seconds: 1);

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  static const headlineStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white);
  static const headline2Style =
      TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white);
  static const savedAddressLocationStyle =
  TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white);
  // static const detailsStyle =
  //     TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white);
  static const prayerStyle =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor);
  static const highlightedDetailsStyle = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w500, color: highlightedTextColor);

  String hadithOfTheDay = "";

  Widget metaData = DataTable(
      columns: [DataColumn(label: Text("")), DataColumn(label: Text(""))],
      rows: []);

  List<Map<String, dynamic>> jsonTimings =
      List<Map<String, dynamic>>.filled(7, <String, dynamic>{});

  String nextPray = 'Fajr';
  DateTime? nextPrayTime;

  List<Map<String, dynamic>> jsonDataDate =
      List<Map<String, dynamic>>.filled(7, {});

  Future<bool> FetchAPI() async {
    EasyLoading.show(status: 'loading...', dismissOnTap: false);

    // Get Saved location from IP or shared preferences
    final SharedPreferences prefs = await _prefs;
    Map<String, dynamic> savedLocation = await api_utils.getSavedLocation();
    if (savedLocation["error"] != "") {
      EasyLoading.showError("Location_Missing_Error".tr(),
          duration: const Duration(seconds: 10), dismissOnTap: true);
      return false;
    }

    try {
      for (int dayNumber = 0;
          dayNumber < NUMBER_OF_DAYS;
          dayNumber++) {
        dynamic jsonData;
        Map<String, dynamic> dataFromDay =
            await api_utils.getDataFromDay(dayNumber, savedLocation);
        if (dataFromDay["error"] != "") {
          EasyLoading.showError("Something went wrong $dataFromDay",
              dismissOnTap: true);
          return false;
        }
        jsonData = dataFromDay["jsonData"];

        Map<String, dynamic> timings = jsonData['data']['timings'];

        // Calculate next prayer times for next praying
        if (dayNumber == 0) {
          int prayerIndex = 0;
          bool found = false;
          DateTime currentDateTime = DateTime.now();
          for (prayerIndex = 0;
              prayerIndex < PRAYER_NAMES.length;
              prayerIndex++) {
            String name = PRAYER_NAMES[prayerIndex];
            DateTime constructedDateTime =
                helper.constructDateTime(timings[name].toString());
            if (constructedDateTime.compareTo(currentDateTime) > 0) {
              found = true;
              nextPrayTime = constructedDateTime;
              break;
            }
          }
          if (found) {
            nextPray = PRAYER_NAMES[prayerIndex];
          } else {
            nextPray = PRAYER_NAMES[0];
            nextPrayTime = helper.constructDateTime(
                timings[PRAYER_NAMES[0]].toString());
            nextPrayTime = nextPrayTime?.add(const Duration(days: 1));
          }
        }

        //24 System check
        jsonData['data']['timings'] =
            await api_utils.getTimings24System(timings);

        if (!kIsWeb) {
          if (Platform.isAndroid && dayNumber == 0) {
            homewidget_utils.updateHomePage(
                jsonData['data']['timings'], jsonData['data']['date']);
          }
        }
        try {
          setState(() {
            // Only call setstate once
            jsonDataDate[dayNumber] = jsonData['data']['date'];
            jsonTimings[dayNumber] = jsonData['data']['timings'];
            metaData = processMetaData(jsonData['data']['meta']);
            savedLocationAddress = helper.getAddressLocation(savedLocation);
          });
          resetTimer();
          EasyLoading.dismiss();
        } catch (e) {
          print("Something went wrong $e");
        }
      }
      await helper.updateLastFetchedDate(prefs);
      BackgroundFetch.start().then((int status) {
        if (kDebugMode) {
          print('[BackgroundFetch] start success: $status');
        }
      }).catchError((e) {
        if (kDebugMode) {
          print('[BackgroundFetch] start FAILURE: $e');
        }
      });
      return true;
    } catch (e) {
      try {
        EasyLoading.dismiss();
        EasyLoading.showError("Something went wrong $e", dismissOnTap: true);
      } catch (e) {
        print("Something went wrong $e");
      }
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

  final pageController = PageController(viewportFraction: 0.8, keepPage: true);
  final daysListViewController = ScrollController();
  final pages = List.generate(7, (index) => Container());

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      dialogStyle: UpgradeDialogStyle.cupertino,
      child: RefreshIndicator(
        onRefresh: () {
          return FetchAPI();
        },
        child: Scaffold(
          backgroundColor: interpolatedColor3,
          drawer: Drawer(
            backgroundColor: thirdColor,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                drawerHeader,
                Visibility(
                  visible: !kIsWeb,
                  child: Column(
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
                      title: const Text(
                        'Home_Panel_Dua',
                        style: TextStyle(color: textColor),
                      ).tr(),
                      trailing: Image.asset(
                        "assets/dua/dua.png",
                        width: 24,
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const DuaPageClass()),
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
                        'Home_Panel_Azkar',
                        style: TextStyle(color: textColor),
                      ).tr(),
                      trailing: Image.asset(
                        "assets/azkar/azkar.png",
                        width: 24,
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AzkarPageClass()),
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
                        // helper.invalidateTodayCachedData(_prefs);
                        var location = await shared_preference_methods
                            .getStringData(_prefs, 'location', true);
                        if (location != null) {
                          FetchAPI();
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
                    ListTile(
                      title: const Text('Home_Panel_Hadiths',
                          style: TextStyle(color: textColor))
                          .tr(),
                      trailing: Image.asset(
                        "assets/hadith/hadith.png",
                        width: 24,
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HadithHomePageClass()),
                        );
                      },
                    ),
                    const Divider(
                      color: textColor,
                    ),
                    Column(
                      children: [
                        ListTile(
                          title: const Text(
                            'Home_Panel_Share',
                            style: TextStyle(color: textColor),
                          ).tr(),
                          trailing: const Icon(
                            Icons.share,
                            color: textColor,
                            size: 24,
                          ),
                          onTap: () async {
                            share_utils.shareApp();
                          },
                        ),
                        const Divider(
                          color: textColor,
                        ),
                      ],
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
            actions: [
              Visibility(
                visible: hadithOfTheDay != "",
                child: AdvancedRainbowGlowButton(
                    assetPath: "assets/hadith/bubble.png",
                    onPressed: () => showDialog<String>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16.0))),
                        backgroundColor: Colors.grey[200],
                        title: Column(
                          children: [
                            Center(child: Text('HOME_HADITH_TITLE'.tr())),
                            const Divider(),
                          ],
                        ),
                        content: QuickHadithCardPageClass(hadith: hadithOfTheDay,),
                        actions: <Widget>[
                          TextButton(onPressed: () => Navigator.pop(context, 'X'), child: const Text('X')),
                        ],
                      ),
                    ),
                    size: 35,
                    maxGlowRadius: 15,
                    animationDuration: const Duration(seconds: 10),
                ),
              )
            ],
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor,
                  interpolatedColor5,
                  interpolatedColor6,
                  interpolatedColor7,
                  thirdColor,
                  interpolatedColor1,
                  interpolatedColor2,
                  interpolatedColor3,
                  // interpolatedColor4,
                ],
              ),
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: <Widget>[
                    // Head for location
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 20,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(""),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(25)),
                                    ),
                                    backgroundColor: thirdColor,
                                    builder: (BuildContext context) {
                                      return Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Align(
                                            alignment: Alignment.center,
                                            heightFactor: 2,
                                            child: AutoSizeText(
                                              "Home_Page_Meta_Title".tr(),
                                              style: headline2Style,
                                            ),
                                          ),
                                          Card(
                                            elevation: 20,
                                            color: primaryColor,
                                            shadowColor: thirdColor,
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: metaData,
                                            ),
                                          ),
                                          const Divider(
                                            height: 50,
                                          ),
                                        ],
                                      );
                                    });
                              },
                              child: Align(
                                alignment: Alignment.center,
                                child: AutoSizeText(
                                  savedLocationAddress,
                                  style: savedAddressLocationStyle,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                  onPressed: () async {
                                    stopTimer();
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              SettingsPageClass(prefs: _prefs)),
                                    );
                                    // helper.invalidateTodayCachedData(_prefs);
                                    var location = await shared_preference_methods
                                        .getStringData(_prefs, 'location', true);
                                    if (location != null) {
                                      FetchAPI();
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.settings,
                                    color: textColor,
                                    size: 24,
                                  )),
                            ),
                          )
                        ],
                      ),
                    ),
                    daysOfWeekWidget(),
                    // Page view for prayer times
                    SizedBox(
                      width: 800,
                      height: 520,
                      child: PageView.builder(
                        controller: pageController,
                        itemCount: 7,
                        itemBuilder: (_, index) {
                          return prayerTimingPage(index);
                        },
                        onPageChanged: (value){
                          if (!mounted) return;
                          setState(() {
                            _selectedDayIndex = value;
                            double convertedValue = daysListViewController.position.maxScrollExtent / 7;
                            daysListViewController.animateTo(convertedValue*((value==0)?0:value+1), duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
                          });
                        },
                      ),
                    ),
                    // Disclaimer
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Home_Page_Declaration".tr(),
                          style: const TextStyle(color: textColor,fontSize: 12),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget daysOfWeekWidget() {
    return SizedBox(
      height: 85, // Adjust height to fit content + margin
      child: ListView.builder(
        controller: daysListViewController,
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (BuildContext context, int index) {
          return _buildDayItem(index);
        },
      ),
    );
  }

  Widget _buildDayItem(int index) {
    DateTime today = DateTime.now();
    DateTime itemDate = today.add(Duration(days: index));
    String dayText;
    String dayNumberText = itemDate.day.toString();
    List<String> shortWeekdays = [
      "Mon",
      "Tue",
      "Wed",
      "Thu",
      "Fri",
      "Sat",
      "Sun"
    ];
    if (index == 0) {
      dayText = "Today".tr();
    } else {
      // DateTime.weekday returns 1 for Monday, 7 for Sunday.
      dayText = shortWeekdays[itemDate.weekday - 1].tr();
    }
    bool isSelected = _selectedDayIndex == index;
    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        setState(() {
          _selectedDayIndex = index;
        });
        pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      },
      child: Container(
        width: 70, // Adjust width as needed
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: isSelected ? highlightedColor : primaryColor.withOpacity(0.7),
          borderRadius: BorderRadius.circular(15.0),
          border: Border.all(
            color: isSelected ? highlightedColor : primaryColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AutoSizeText(
              dayText,
              style: TextStyle(
                color: isSelected ? Colors.white : textColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            AutoSizeText(
              dayNumberText,
              style: TextStyle(
                color: isSelected ? Colors.white : textColor.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget prayerTimingPage(int daynumber) {
    return Container(
      color: Colors.transparent,
      child: Card(
        borderOnForeground: false,
        shadowColor: Colors.transparent,
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Column(
              mainAxisSize: MainAxisSize.min, children: <Widget>[
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Center(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AutoSizeText(
                        helper.constructDateFormat(jsonDataDate[daynumber]["gregorian"]?["month"]?["en"] ?? "Month",
                          jsonDataDate[daynumber]["gregorian"]?["date"] ??
                              "gregorian"),
                        style: const TextStyle(
                            color: textColor, fontWeight: FontWeight.bold),
                        maxLines: 1,
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
                        helper.constructDateFormat((jsonDataDate[daynumber]["hijri"]?["month"]?["en"] ??
                            "Month")
                            , jsonDataDate[daynumber]["hijri"]?["date"] ?? "hijri"),
                        style: const TextStyle(
                            color: textColor, fontWeight: FontWeight.bold),
                        maxLines: 1,
                      ),
                    ],
                  )),
                ),
              ],
            ),
            Visibility(
              visible: daynumber == 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0,8.0,0,8.0),
                child: Center(
                  child: AutoSizeText("${"Home_Page_Next_Prayer".tr()}:", style: prayerStyle,),
                ),
              )
            ),
            Visibility(
              visible: daynumber == 0,
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
              height: 15,
              thickness: 5,
              color: dividerColor,
            ),
            RefreshIndicator(
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: PRAYER_NAMES.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Column(
                        children: [
                          detailsRow(
                              PRAYER_NAMES[index],
                              jsonTimings[daynumber]
                                      [PRAYER_NAMES[index]] ??
                                  "-",
                              daynumber),
                        ],
                      );
                    }),
                onRefresh: () {
                  return FetchAPI();
                }),
          ]),
        ),
      ),
    );
  }

  Widget detailsRow(String headText, String detailsText, int dayNumber) {
    return SizedBox(
      height: 55,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(
            color: nextPray == headText ? (dayNumber == 0) ? highlightedBoxesBorderColor: boxesBorderColor : boxesBorderColor,
          ),
        ),
        // shadowColor: Colors.blueGrey,
        color: primaryColor,
        elevation: 15,
        margin: const EdgeInsets.all(5),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.3,
                child: Center(
                  child: AutoSizeText(
                    "${headText.tr()}:",
                    style: nextPray == headText
                        ? (dayNumber == 0)
                            ? highlightedDetailsStyle
                            : prayerStyle
                        : prayerStyle,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: SizedBox(
                width: MediaQuery.of(context).size.width / 2 * 3,
                child: Center(
                  child: AutoSizeText(detailsText,
                      textDirection: TextDirection.ltr,
                      style: nextPray == headText
                          ? (dayNumber == 0)
                              ? highlightedDetailsStyle
                              : prayerStyle
                          : prayerStyle,
                      maxLines: 1),
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
          if (!mounted) return;
          setState(() async {
            await FetchAPI();
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
      if (!mounted) return;
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
            color: primaryColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            time,
            style: highlightedDetailsStyle.copyWith(fontSize: 20),
          ),
        )
      ],
    );
  }

  Widget processMetaData(meta) {
    List<DataRow> datarows = [];
    datarows.add(buildMetaRow(
        "Home_Page_Meta_Timezone".tr(), meta["timezone"]?.toString() ?? ""));
    // datarows.add(buildMetaRow(
    //     "Home_Page_Meta_Longitude".tr(), meta["longitude"]?.toString() ?? ""));
    // datarows.add(buildMetaRow(
    //     "Home_Page_Meta_Latitude".tr(), meta["latitude"]?.toString() ?? ""));
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
}
