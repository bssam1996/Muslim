import 'dart:async';
import 'dart:core';
import 'dart:io' show Platform;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/azkar/azkar_page.dart';
import 'package:muslim/UI/biographies/biography_page.dart';
import 'package:muslim/UI/daily_routine/daily_routine_page.dart';
import 'package:muslim/UI/dua/dua_page.dart';
import 'package:muslim/UI/hadith/main_page.dart';
import 'package:muslim/UI/month/months_page.dart';
import 'package:muslim/UI/mosque/nearest_mosque_page.dart';
import 'package:muslim/UI/prayer_notifications/prayer_notifications.dart';
import 'package:muslim/UI/contact/contact.dart';
import 'package:muslim/UI/qiblah/qiblah_page.dart';
import 'package:muslim/UI/quran/quran_page.dart';
import 'package:muslim/UI/quiz/quiz_page.dart';
import 'package:muslim/UI/radio/radio_page.dart';
import 'package:muslim/shared/constants.dart';
import 'package:muslim/shared/home_action_grid.dart';
import 'package:muslim/shared/web_home_style.dart';
import 'package:muslim/shared/responsive_web_layout.dart';
import 'package:muslim/utils/api_utils.dart' as api_utils;
import 'package:muslim/utils/hadith_utils.dart';
import 'package:muslim/utils/review_utils.dart' as review_utils;
import 'package:muslim/utils/share_utils.dart' as share_utils;
import 'UI/hadith/quick_hadith_card.dart';
import 'UI/prayer_metadata_sheet.dart';
import 'UI/settings/settings.dart';
import 'UI/home/pilgrimage_menu_entries.dart';
import 'utils/helper.dart' as helper;
import 'utils/homewidget_utils.dart' as homewidget_utils;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/shared_preference_methods.dart' as shared_preference_methods;
import 'package:home_widget/home_widget.dart';
import 'package:easy_localization/easy_localization.dart' as easy_localization;
import 'package:upgrader/upgrader.dart';
// import 'package:muslim/shared/rainbow_button.dart';
import 'package:muslim/UI/month/helper.dart' as prayer_calendar_model;

class _UtilityItem {
  const _UtilityItem({
    required this.titleKey,
    required this.assetPath,
    required this.onTap,
  });

  final String titleKey;
  final String assetPath;
  final VoidCallback onTap;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool get _styledWeb => useWebHomeStyle(context);
  final PageController _pageController = PageController(
    viewportFraction: kIsWeb ? 1 : 0.8,
    keepPage: true,
  );

  @override
  void dispose() {
    refreshTimer?.cancel();
    _pageController.dispose();
    daysListViewController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      HomeWidget.setAppGroupId(HOME_WIDGET_GROUP_ID);
    }
    EasyLoading.showInfo("Loading settings...");
    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (!mounted) return;
        FetchAPI().then((value) async {
          if (value == false) {
            // FetchAPI can fail because the prayer-time service is unavailable,
            // not only because location is missing. Open Settings only when the
            // saved location itself cannot be obtained or verified.
            final Map<String, dynamic> savedLocation = await api_utils
                .getSavedLocation();
            if (savedLocation["error"] == "") {
              return;
            }
            stopTimer();
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsPageClass(prefs: _prefs),
              ),
            );
            var location = await shared_preference_methods.getStringData(
              _prefs,
              'location',
              true,
            );
            if (location != null) {
              FetchAPI();
            } else {
              EasyLoading.showError(
                "Location_Missing_Error".tr(),
                duration: const Duration(seconds: 15),
                dismissOnTap: true,
              );
            }
          } else {
            await _maybeShowReviewPrompt();
          }
        });
        getRandomHadith().then((value) {
          if (!mounted) return;
          setState(() {
            hadithOfTheDay = value;
          });
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
  bool _requestingReview = false;
  bool _reviewPromptVisible = false;
  Timer? refreshTimer;
  Duration refreshDuration = const Duration(seconds: 1);

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  static const headline2Style = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  static const savedAddressLocationStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  // static const detailsStyle =
  //     TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white);
  static const prayerStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textColor,
  );
  static const highlightedDetailsStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: highlightedTextColor,
  );

  RandomHadith? hadithOfTheDay;

  Map<String, dynamic> prayerMetadata = <String, dynamic>{};

  List<Map<String, dynamic>> jsonTimings = List<Map<String, dynamic>>.filled(
    7,
    <String, dynamic>{},
  );

  String nextPray = 'Fajr';
  DateTime? nextPrayTime;

  List<Map<String, dynamic>> jsonDataDate = List<Map<String, dynamic>>.filled(
    7,
    {},
  );

  Future<void> _maybeShowReviewPrompt() async {
    if (_reviewPromptVisible || _requestingReview) {
      return;
    }

    final bool shouldShow = await review_utils.shouldShowReviewPrompt(_prefs);
    if (!mounted || !shouldShow) {
      return;
    }

    setState(() {
      _reviewPromptVisible = true;
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: settingsWidgetBGColor,
          title: Text(
            "Review_Prompt_Title".tr(),
            style: const TextStyle(color: textColor),
          ),
          content: Text(
            "Review_Prompt_Description".tr(),
            style: const TextStyle(color: highlightedColor),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await review_utils.deferReviewPrompt(
                  _prefs,
                  review_utils.reviewDeclinedCooldown,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text("Review_Prompt_No".tr()),
            ),
            TextButton(
              onPressed: () async {
                await review_utils.deferReviewPrompt(
                  _prefs,
                  review_utils.reviewLaterCooldown,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text("Review_Prompt_Later".tr()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_requestReview());
              },
              child: Text("Review_Prompt_Yes".tr()),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _reviewPromptVisible = false;
    });
  }

  Future<void> _requestReview() async {
    if (_requestingReview) {
      return;
    }
    setState(() {
      _requestingReview = true;
    });

    final review_utils.ReviewRequestResult result = await review_utils
        .requestReviewIfAllowed(_prefs);
    if (!mounted) return;

    setState(() {
      _requestingReview = false;
    });

    switch (result) {
      case review_utils.ReviewRequestResult.requested:
      case review_utils.ReviewRequestResult.storeListingOpened:
        EasyLoading.showSuccess("Review_Thanks".tr());
        break;
      case review_utils.ReviewRequestResult.noNetwork:
        EasyLoading.showError(
          "No_Internet_Error".tr(),
          duration: const Duration(seconds: 15),
          dismissOnTap: true,
        );
        break;
      case review_utils.ReviewRequestResult.alreadySubmitted:
        break;
      case review_utils.ReviewRequestResult.web:
      case review_utils.ReviewRequestResult.unavailable:
      case review_utils.ReviewRequestResult.failed:
        EasyLoading.showError("Review_Unavailable".tr(), dismissOnTap: true);
        break;
    }
  }

  Future<void> _openStoreListingForReview() async {
    if (_requestingReview) {
      return;
    }
    setState(() {
      _requestingReview = true;
    });

    final review_utils.ReviewRequestResult result = await review_utils
        .openStoreListingForReview();
    if (!mounted) return;

    setState(() {
      _requestingReview = false;
    });

    switch (result) {
      case review_utils.ReviewRequestResult.storeListingOpened:
        EasyLoading.showSuccess("Review_Thanks".tr());
        break;
      case review_utils.ReviewRequestResult.noNetwork:
        EasyLoading.showError(
          "No_Internet_Error".tr(),
          duration: const Duration(seconds: 15),
          dismissOnTap: true,
        );
        break;
      case review_utils.ReviewRequestResult.requested:
      case review_utils.ReviewRequestResult.alreadySubmitted:
      case review_utils.ReviewRequestResult.web:
      case review_utils.ReviewRequestResult.unavailable:
      case review_utils.ReviewRequestResult.failed:
        EasyLoading.showError("Review_Unavailable".tr(), dismissOnTap: true);
        break;
    }
  }

  Future<bool> FetchAPI() async {
    EasyLoading.show(status: 'loading...', dismissOnTap: false);

    // Get the saved, verified prayer-time location.
    final SharedPreferences prefs = await _prefs;
    Map<String, dynamic> savedLocation = await api_utils.getSavedLocation();
    if (savedLocation["error"] != "") {
      EasyLoading.showError(
        savedLocation["error"] == "Settings_Location_City_Country_Unavailable"
            ? "Settings_Location_City_Country_Unavailable".tr()
            : "Location_Missing_Error".tr(),
        duration: const Duration(seconds: 15),
        dismissOnTap: true,
      );
      return false;
    }

    try {
      for (int dayNumber = 0; dayNumber < NUMBER_OF_DAYS; dayNumber++) {
        dynamic jsonData;
        Map<String, dynamic> dataFromDay = await api_utils.getDataFromDay(
          dayNumber,
          savedLocation,
        );
        if (dataFromDay["error"] != "") {
          EasyLoading.showError(
            dataFromDay["error"].toString(),
            dismissOnTap: true,
          );
          return false;
        }
        jsonData = dataFromDay["jsonData"];

        Map<String, dynamic> timings = jsonData['data']['timings'];

        // Calculate next prayer times for next praying
        if (dayNumber == 0) {
          int prayerIndex = 0;
          bool found = false;
          DateTime currentDateTime = DateTime.now();
          for (
            prayerIndex = 0;
            prayerIndex < PRAYER_NAMES.length;
            prayerIndex++
          ) {
            String name = PRAYER_NAMES[prayerIndex];
            DateTime constructedDateTime = helper.constructDateTime(
              timings[name].toString(),
            );
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
              timings[PRAYER_NAMES[0]].toString(),
            );
            nextPrayTime = nextPrayTime?.add(const Duration(days: 1));
          }
        }

        //24 System check
        jsonData['data']['timings'] = await api_utils.getTimings24System(
          timings,
        );

        if (!kIsWeb) {
          if (Platform.isAndroid && dayNumber == 0) {
            homewidget_utils.updateHomePage(
              jsonData['data']['timings'],
              jsonData['data']['date'],
            );
          }
        }
        try {
          setState(() {
            // Only call setstate once
            jsonDataDate[dayNumber] = jsonData['data']['date'];
            jsonTimings[dayNumber] = jsonData['data']['timings'];
            prayerMetadata = jsonData['data']['meta'] is Map
                ? Map<String, dynamic>.from(jsonData['data']['meta'] as Map)
                : <String, dynamic>{};
            savedLocationAddress = helper.getAddressLocation(savedLocation);
          });
          resetTimer();
          EasyLoading.dismiss();
        } catch (e) {
          print("Something went wrong $e");
        }
      }
      await helper.updateLastFetchedDate(prefs);
      // Handle Notification
      await helper.handleNotifications(_prefs, jsonTimings);
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
      backgroundColor: primaryColor,
      child: ClipOval(
        child: Image.asset(
          'assets/icon/icon.png',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                return const Icon(
                  Icons.mosque_outlined,
                  color: highlightedTextColor,
                  size: 42,
                );
              },
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

  // final pageController = PageController(viewportFraction: 0.8, keepPage: true);
  final daysListViewController = ScrollController();
  // final pages = List.generate(7, (index) => Container());

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      dialogStyle: UpgradeDialogStyle.cupertino,
      child: RefreshIndicator(
        onRefresh: () {
          return FetchAPI();
        },
        child: Scaffold(
          backgroundColor: _styledWeb ? webCanvasColor : interpolatedColor3,
          drawer: Drawer(
            backgroundColor: thirdColor,
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  drawerHeader,
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
                              builder: (context) => const QuranPageClass(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: textColor),
                    ],
                  ),
                  ListTile(
                    title: const Text(
                      'Home_Panel_Hadiths',
                      style: TextStyle(color: textColor),
                    ).tr(),
                    trailing: Image.asset(
                      "assets/hadith/hadith.png",
                      width: 24,
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HadithHomePageClass(),
                        ),
                      );
                    },
                  ),
                  const Divider(color: textColor),
                  Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Home_Panel_Dua',
                          style: TextStyle(color: textColor),
                        ).tr(),
                        trailing: Image.asset("assets/dua/dua.png", width: 24),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DuaPageClass(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: textColor),
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
                              builder: (context) => const AzkarPageClass(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: textColor),
                    ],
                  ),
                  const PilgrimageMenuEntries(),
                  ListTile(
                    title: const Text(
                      'Biography_Title',
                      style: TextStyle(color: textColor),
                    ).tr(),
                    trailing: Image.asset(biographyIcon, width: 24),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BiographyPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(color: textColor),
                  Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Home_Panel_Settings',
                          style: TextStyle(color: textColor),
                        ).tr(),
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
                                  SettingsPageClass(prefs: _prefs),
                            ),
                          );
                          // helper.invalidateTodayCachedData(_prefs);
                          var location = await shared_preference_methods
                              .getStringData(_prefs, 'location', true);
                          if (location != null) {
                            FetchAPI();
                          }
                        },
                      ),
                      const Divider(color: textColor),
                      Visibility(
                        visible: (!kIsWeb && Platform.isAndroid),
                        child: ListTile(
                          title: const Text(
                            'Home_Panel_Prayer_Notifications',
                            style: TextStyle(color: textColor),
                          ).tr(),
                          trailing: const Icon(
                            Icons.notifications,
                            color: textColor,
                            size: 24,
                          ),
                          onTap: () async {
                            stopTimer();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PrayerNotificationsPageClass(prefs: _prefs),
                              ),
                            );
                            var location = await shared_preference_methods
                                .getStringData(_prefs, 'location', true);
                            if (location != null) {
                              FetchAPI();
                            }
                          },
                        ),
                      ),
                      const Divider(color: textColor),
                      ListTile(
                        title: const Text(
                          'Home_Panel_Contact',
                          style: TextStyle(color: textColor),
                        ).tr(),
                        trailing: const Icon(
                          Icons.contact_support,
                          color: textColor,
                          size: 24,
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ContactPageClass(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: textColor),
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
                          const Divider(color: textColor),
                          ListTile(
                            title: const Text(
                              'Home_Panel_Rate',
                              style: TextStyle(color: textColor),
                            ).tr(),
                            trailing: Image.asset(
                              'assets/rating/rating.png',
                              width: 24,
                            ),
                            onTap: () {
                              unawaited(_openStoreListingForReview());
                            },
                          ),
                          const Divider(color: textColor),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          appBar: AppBar(
            backgroundColor: _styledWeb ? webCanvasColor : primaryColor,
            elevation: _styledWeb ? 0 : null,
            title: Text(
              widget.title.tr(),
              style: const TextStyle(color: textColor),
            ),
            centerTitle: !_styledWeb,
            iconTheme: const IconThemeData(color: textColor),
            // actions: [
            //   Visibility(
            //     visible: hadithOfTheDay != "",
            //     child: AdvancedRainbowGlowButton(
            //         assetPath: "assets/hadith/bubble.png",
            //         onPressed: () => showDialog<String>(
            //           context: context,
            //           builder: (BuildContext context) => AlertDialog(
            //             shape: const RoundedRectangleBorder(
            //                 borderRadius: BorderRadius.all(Radius.circular(16.0))),
            //             backgroundColor: Colors.grey[200],
            //             title: Column(
            //               children: [
            //                 Center(child: Text('HOME_HADITH_TITLE'.tr())),
            //                 const Divider(),
            //               ],
            //             ),
            //             content: QuickHadithCardPageClass(hadith: hadithOfTheDay,),
            //             actions: <Widget>[
            //               TextButton(onPressed: () => Navigator.pop(context, 'X'), child: const Text('X')),
            //             ],
            //           ),
            //         ),
            //         size: 35,
            //         maxGlowRadius: 15,
            //         animationDuration: const Duration(seconds: 10),
            //     ),
            //   )
            // ],
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _styledWeb
                    ? const [webCanvasColor, Color(0xFF191C32)]
                    : const [
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
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.all(_styledWeb ? 24 : 16),
                  child: _buildHomeContent(_pageController),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent(PageController pageController) {
    final dashboard = HomeDashboardLayout(
      allowWideLayout: kIsWeb,
      prayerPanel: _buildPrayerPanel(pageController),
      contentPanel: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedOpacity(
            opacity: hadithOfTheDay != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 750),
            child: hadithOfTheDay == null
                ? const SizedBox.shrink()
                : QuickHadithCardPageClass(hadith: hadithOfTheDay!),
          ),
          if (_styledWeb) _buildReadingSection(),
          _buildActivitiesSection(),
          _buildUtilitiesSection(),
          // Visibility(
          //   visible: hadithOfTheDay != "",
          //   child: QuickHadithCardPageClass(hadith: hadithOfTheDay,),
          // ),
          // Text(
          //   "Home_Page_Declaration".tr(),
          //   style: const TextStyle(color: textColor,fontSize: 12),
          // ),
        ],
      ),
    );
    if (!_styledWeb) return dashboard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Home_Web_Overview'.tr(),
                style: const TextStyle(
                  color: webAccentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Home_Web_Heading'.tr(),
                style: const TextStyle(
                  color: textColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Home_Web_Description'.tr(),
                style: const TextStyle(
                  color: webMutedColor,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        dashboard,
      ],
    );
  }

  Widget _buildPrayerPanel(PageController pageController) {
    return WebPrayerPanel(
      styled: _styledWeb,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Head for location
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  if (!_styledWeb) const SizedBox(width: 48),
                  if (_styledWeb) ...[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: webAccentColor,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          backgroundColor: thirdColor,
                          builder: (BuildContext context) {
                            return PrayerMetadataSheet(
                              locationName: savedLocationAddress,
                              metadata: prayerMetadata,
                            );
                          },
                        );
                      },
                      child: Align(
                        alignment: _styledWeb
                            ? AlignmentDirectional.centerStart
                            : Alignment.center,
                        child: AutoSizeText(
                          savedLocationAddress,
                          style: _styledWeb
                              ? savedAddressLocationStyle.copyWith(fontSize: 20)
                              : savedAddressLocationStyle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () async {
                          stopTimer();
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SettingsPageClass(prefs: _prefs),
                            ),
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
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            daysOfWeekWidget(pageController),
            timeLeftWidget(),
            if (_styledWeb)
              Flexible(
                fit: constraints.hasBoundedHeight
                    ? FlexFit.tight
                    : FlexFit.loose,
                child: SizedBox(
                  height: constraints.hasBoundedHeight ? null : 380,
                  child: _buildPrayerPager(pageController),
                ),
              )
            else
              SizedBox(
                height: _styledWeb ? 380 : 400,
                width: double.infinity,
                child: _buildPrayerPager(pageController),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerPager(PageController pageController) {
    return PageView.builder(
      key: const PageStorageKey('home_prayer_pager'),
      controller: pageController,
      itemCount: 7,
      itemBuilder: (_, index) {
        if (jsonTimings[index].isEmpty || jsonDataDate[index].isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return prayerTimingPage(index);
      },
      onPageChanged: (value) {
        if (!mounted) return;
        setState(() {
          _selectedDayIndex = value;
          double convertedValue =
              daysListViewController.position.maxScrollExtent / 7;
          daysListViewController.animateTo(
            convertedValue * ((value == 0) ? 0 : value + 1),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeIn,
          );
        });
      },
    );
  }

  Widget _buildReadingSection() {
    final pages = <(String, String, IconData, Widget)>[
      (
        'Home_Panel_Quran',
        'assets/quran/quran.png',
        Icons.menu_book_rounded,
        const QuranPageClass(),
      ),
      (
        'Home_Panel_Azkar',
        'assets/azkar/azkar.png',
        Icons.wb_sunny_outlined,
        const AzkarPageClass(),
      ),
      (
        'Home_Panel_Dua',
        'assets/dua/dua.png',
        Icons.volunteer_activism_outlined,
        const DuaPageClass(),
      ),
      (
        'Home_Panel_Hadiths',
        'assets/hadith/hadith.png',
        Icons.auto_stories_outlined,
        const HadithHomePageClass(),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading('Home_Web_Reading'),
          HomeActionGrid(
            compact: true,
            maxColumns: 2,
            children: [
              for (final (title, asset, icon, page) in pages)
                HomeActionTile(
                  title: title.tr(),
                  assetPath: asset,
                  icon: icon,
                  styled: true,
                  onTap: () => Navigator.of(
                    context,
                  ).push<void>(MaterialPageRoute(builder: (_) => page)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String key) => Padding(
    padding: EdgeInsets.only(left: 4, right: 4, bottom: _styledWeb ? 12 : 8),
    child: Text(
      key.tr(),
      style: _styledWeb
          ? const TextStyle(
              color: webMutedColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )
          : headline2Style,
    ),
  );

  IconData _actionIcon(String asset) => switch (asset) {
    'assets/daily_routine/daily-routine.png' => Icons.task_alt_rounded,
    'assets/quiz/quiz.png' => Icons.quiz_outlined,
    'assets/mosque/mosque_home.png' => Icons.mosque_outlined,
    'assets/prayercalender/prayercalender.png' => Icons.calendar_month_outlined,
    'assets/radio/radio128.png' => Icons.radio_outlined,
    _ => Icons.explore_outlined,
  };

  Widget _buildUtilitiesSection() {
    final utilityItems = <_UtilityItem>[
      if (!kIsWeb)
        _UtilityItem(
          titleKey: 'Home_Panel_Qiblah',
          assetPath: 'assets/qiblah/compass.png',
          onTap: _openQiblahPage,
        ),
      _UtilityItem(
        titleKey: 'Home_Utilities_Find_Nearest_Mosque',
        assetPath: 'assets/mosque/mosque_home.png',
        onTap: _openNearestMosquePage,
      ),
      _UtilityItem(
        titleKey: 'Home_Panel_Prayer_Calendar',
        assetPath: 'assets/prayercalender/prayercalender.png',
        onTap: _openMonthlyPrayerTimingsPage,
      ),
      _UtilityItem(
        titleKey: 'Home_Panel_Radio',
        assetPath: 'assets/radio/radio128.png',
        onTap: _openRadioPage,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionHeading('Home_Utilities_Title'),
          HomeActionGrid(
            compact: kIsWeb && MediaQuery.sizeOf(context).width >= 600,
            children: [
              for (final item in utilityItems)
                HomeActionTile(
                  title: item.titleKey.tr(),
                  styled: _styledWeb,
                  icon: _actionIcon(item.assetPath),
                  assetPath: item.assetPath,
                  onTap: item.onTap,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesSection() {
    final activityItems = <_UtilityItem>[
      _UtilityItem(
        titleKey: 'Home_Activities_Daily_Routine',
        assetPath: 'assets/daily_routine/daily-routine.png',
        onTap: _openDailyRoutinePage,
      ),
      _UtilityItem(
        titleKey: 'Home_Activities_Quiz',
        assetPath: 'assets/quiz/quiz.png',
        onTap: _openQuizPage,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionHeading('Home_Activities_Title'),
          HomeActionGrid(
            compact: kIsWeb && MediaQuery.sizeOf(context).width >= 600,
            children: [
              for (final item in activityItems)
                HomeActionTile(
                  title: item.titleKey.tr(),
                  styled: _styledWeb,
                  icon: _actionIcon(item.assetPath),
                  assetPath: item.assetPath,
                  onTap: item.onTap,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openQiblahPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QiblahClass()),
    );
  }

  Future<void> _openMonthlyPrayerTimingsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MonthsPageClass()),
    );
  }

  Future<void> _openRadioPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RadioPageClass()),
    );
  }

  Future<void> _openNearestMosquePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NearestMosquePageClass()),
    );
  }

  Future<void> _openQuizPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizPageClass()),
    );
  }

  Future<void> _openDailyRoutinePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DailyRoutinePageClass(todayTimings: jsonTimings[0]),
      ),
    );
  }

  Widget timeLeftWidget() {
    if (nextPrayTime == null) {
      return Container();
    }
    if (_styledWeb) {
      final remaining = nextPrayTime!.difference(DateTime.now());
      final countdown = ['hour', 'minute', 'second']
          .map((part) => helper.constructTimeLeftSplitted(remaining, part))
          .join(' : ');
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8, bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: webAccentSurface.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Home_Page_Next_Prayer'.tr(),
                    style: const TextStyle(color: webMutedColor, fontSize: 12),
                  ),
                ),
                Text(
                  nextPray.tr(),
                  style: const TextStyle(
                    color: webAccentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              countdown,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: textColor,
                fontSize: 30,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8.0, 0, 8.0),
          child: Center(
            child: AutoSizeText(
              "${"Home_Page_Next_Prayer".tr()}:",
              style: prayerStyle,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: TextDirection.ltr,
          children: [
            buildTimeCard(
              nextPrayTime != null
                  ? (helper.constructTimeLeftSplitted(
                      nextPrayTime!.difference(DateTime.now()),
                      "hour",
                    ))
                  : "-",
            ),
            buildTimeCard(
              nextPrayTime != null
                  ? (helper.constructTimeLeftSplitted(
                      nextPrayTime!.difference(DateTime.now()),
                      "minute",
                    ))
                  : "-",
            ),
            buildTimeCard(
              nextPrayTime != null
                  ? (helper.constructTimeLeftSplitted(
                      nextPrayTime!.difference(DateTime.now()),
                      "second",
                    ))
                  : "-",
            ),
          ],
        ),
      ],
    );
  }

  Widget daysOfWeekWidget(PageController pageController) {
    return SizedBox(
      height: _styledWeb ? 72 : 85,
      child: ListView.builder(
        key: ValueKey("days_of_week"),
        controller: daysListViewController,
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (BuildContext context, int index) {
          return _buildDayItem(index, pageController);
        },
      ),
    );
  }

  Widget _buildDayItem(int index, PageController pageController) {
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
      "Sun",
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
        key: ValueKey("buildDayItem_$index"),
        width: _styledWeb ? 44 : 70,
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        padding: _styledWeb
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8)
            : const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _styledWeb
              ? (isSelected ? webAccentSurface : Colors.transparent)
              : (isSelected ? highlightedColor : primaryColor.withOpacity(0.7)),
          borderRadius: BorderRadius.circular(15.0),
          border: Border.all(
            color: _styledWeb
                ? (isSelected
                      ? webAccentColor.withValues(alpha: .4)
                      : Colors.transparent)
                : (isSelected ? highlightedColor : primaryColor),
            width: 1,
          ),
          boxShadow: _styledWeb
              ? const []
              : [
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
              maxLines: 1,
              minFontSize: _styledWeb ? 9 : 12,
              style: TextStyle(
                fontSize: _styledWeb ? 11 : null,
                color: _styledWeb
                    ? (isSelected ? webAccentColor : webMutedColor)
                    : (isSelected ? Colors.white : textColor),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            AutoSizeText(
              dayNumberText,
              style: TextStyle(
                fontSize: _styledWeb ? 13 : null,
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
      key: ValueKey("prayer_timing_page_$daynumber"),
      color: Colors.transparent,
      child: Card(
        borderOnForeground: false,
        shadowColor: Colors.transparent,
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
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
                            helper.constructDateFormat(
                              jsonDataDate[daynumber]["gregorian"]?["month"]?["en"] ??
                                  "Month",
                              jsonDataDate[daynumber]["gregorian"]?["date"] ??
                                  "gregorian",
                            ),
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return prayer_calendar_model.showdialog();
                                },
                              );
                            },
                            child: AutoSizeText(
                              helper.constructDateFormat(
                                (jsonDataDate[daynumber]["hijri"]?["month"]?["en"] ??
                                    "Month"),
                                jsonDataDate[daynumber]["hijri"]?["date"] ??
                                    "hijri",
                              ),
                              style: const TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                height: _styledWeb ? 24 : 15,
                thickness: _styledWeb ? 1 : 5,
                color: _styledWeb ? webBorderColor : dividerColor,
              ),
              if (_styledWeb)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _prayerRows(daynumber),
                  ),
                )
              else
                Column(children: _prayerRows(daynumber)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _prayerRows(int daynumber) => List.generate(
    PRAYER_NAMES.length,
    (index) => detailsRow(
      PRAYER_NAMES[index],
      jsonTimings[daynumber][PRAYER_NAMES[index]] ?? '-',
      daynumber,
    ),
  );

  Widget detailsRow(String headText, String detailsText, int dayNumber) {
    if (_styledWeb) {
      final highlighted = nextPray == headText && dayNumber == 0;
      return Container(
        height: 48,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: highlighted ? webAccentSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              highlighted
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 14,
              color: highlighted
                  ? webAccentColor
                  : webMutedColor.withValues(alpha: .4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                headText.tr(),
                style: TextStyle(
                  color: highlighted ? webAccentColor : webMutedColor,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              detailsText,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: highlighted ? webAccentColor : textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 55,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(
            color: nextPray == headText
                ? (dayNumber == 0)
                      ? highlightedBoxesBorderColor
                      : boxesBorderColor
                : boxesBorderColor,
          ),
        ),
        // shadowColor: Colors.blueGrey,
        color: primaryColor,
        elevation: 15,
        margin: const EdgeInsets.all(5),
        child: Row(
          children: [
            Expanded(
              flex: 2,
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
            Expanded(
              flex: 3,
              child: Center(
                child: AutoSizeText(
                  detailsText,
                  textDirection: TextDirection.ltr,
                  style: nextPray == headText
                      ? (dayNumber == 0)
                            ? highlightedDetailsStyle
                            : prayerStyle
                      : prayerStyle,
                  maxLines: 1,
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
          FetchAPI();

          // setState(() async {
          // });
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
            border: Border.all(color: boxesBorderColor),
            color: primaryColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            time,
            style: highlightedDetailsStyle.copyWith(fontSize: 20),
          ),
        ),
      ],
    );
  }
}
