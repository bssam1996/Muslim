import 'shared/prayer_countdown.dart';
import 'shared/content_height_page_view.dart';
import 'shared/prayer_date_header.dart';
import 'shared/prayer_time_row.dart';
import 'package:muslim/shared/app_theme.dart';
import 'dart:async';
import 'dart:core';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/azkar/azkar_page.dart';
import 'package:muslim/UI/prophets/prophets_page.dart';
import 'package:muslim/UI/daily_routine/daily_routine_page.dart';
import 'package:muslim/UI/dua/dua_page.dart';
import 'package:muslim/UI/hadith/main_page.dart';
import 'package:muslim/UI/month/months_page.dart';
import 'package:muslim/UI/mosque/nearest_mosque_page.dart';
import 'package:muslim/UI/qiblah/qiblah_page.dart';
import 'package:muslim/UI/quran/quran_page.dart';
import 'package:muslim/UI/quiz/quiz_page.dart';
import 'package:muslim/UI/radio/radio_page.dart';
import 'package:muslim/shared/constants.dart';
import 'package:muslim/shared/home_action_grid.dart';
import 'package:muslim/shared/retry_notice.dart';
import 'package:muslim/utils/android_startup.dart';
import 'package:muslim/utils/refresh_coordinator.dart';
import 'package:muslim/utils/prayer_schedule.dart';
import 'package:muslim/shared/web_home_style.dart';
import 'package:muslim/shared/responsive_web_layout.dart';
import 'package:muslim/utils/api_utils.dart' as api_utils;
import 'package:muslim/utils/hadith_utils.dart';
import 'package:muslim/utils/review_utils.dart' as review_utils;
import 'package:muslim/utils/share_utils.dart' as share_utils;
import 'UI/hadith/quick_hadith_card.dart';
import 'UI/prayer_metadata_sheet.dart';
import 'UI/settings/settings.dart';
import 'shared/app_navigation.dart';
import 'utils/helper.dart' as helper;
import 'utils/homewidget_utils.dart' as homewidget_utils;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/shared_preference_methods.dart' as shared_preference_methods;
import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  const MyHomePage({super.key, required this.title, this.loadHadith});
  final String title;
  final Future<RandomHadith?> Function()? loadHadith;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool get _styledWeb => useWebHomeStyle(context);
  final PageController _pageController = PageController(
    viewportFraction: kIsWeb ? 1 : 0.8,
    keepPage: true,
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    _clock.dispose();
    _pageController.dispose();
    daysListViewController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startTimer();
    if (!kIsWeb && Platform.isAndroid) {
      HomeWidget.setAppGroupId(HOME_WIDGET_GROUP_ID);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initializeHome());
      unawaited(_loadHadith());
    });
  }

  Future<void> _loadHadith() async {
    final value = await (widget.loadHadith?.call() ?? getRandomHadith());
    if (mounted) setState(() => hadithOfTheDay = value);
  }

  Future<void> _initializeHome() async {
    try {
      final success = await FetchAPI();
      if (!mounted) return;
      if (success) {
        await _maybeShowReviewPrompt();
        return;
      }
      // A failed service request must not redirect a configured user.
      final savedLocation = await api_utils.getSavedLocation();
      if (!mounted || savedLocation['error'] == '') return;
      stopTimer();
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SettingsPageClass(prefs: _prefs)),
      );
      if (mounted) await FetchAPI();
    } catch (error, stack) {
      debugPrint('Home initialization failed: $error\n$stack');
      if (mounted) _markRefreshFailed('Home_Refresh_Error');
    }
  }

  String savedLocationAddress = "-";
  int _selectedDayIndex = 0;
  bool _requestingReview = false;
  bool _reviewPromptVisible = false;
  final RefreshCoordinator _refresh = RefreshCoordinator();
  bool _isRefreshing = false;
  String? _refreshErrorKey;
  String? _prayerDataIdentity;
  DateTime? _loadedPrayerDate;
  final Map<int, PrayerDay> _prayerDays = {};
  final List<bool> _dayErrors = List.filled(7, false);
  final _clock = ValueNotifier<DateTime>(DateTime.now());
  Timer? refreshTimer;
  Duration refreshDuration = const Duration(seconds: 1);

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  TextStyle get headline2Style => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppPalette.of(context).text,
  );
  TextStyle get savedAddressLocationStyle => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppPalette.of(context).text,
  );
  // static const detailsStyle =
  //     TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white);
  TextStyle get prayerStyle => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppPalette.of(context).text,
  );
  TextStyle get highlightedDetailsStyle => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppPalette.of(context).accent,
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
          backgroundColor: AppPalette.of(context).panel,
          title: Text(
            "Review_Prompt_Title".tr(),
            style: TextStyle(color: AppPalette.of(context).text),
          ),
          content: Text(
            "Review_Prompt_Description".tr(),
            style: TextStyle(color: AppPalette.of(context).accent),
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

  Future<bool> FetchAPI({bool automatic = false, bool forceRefresh = false}) =>
      _refresh.run(
        () => _fetchPrayerTimes(forceRefresh: forceRefresh),
        automatic: automatic,
      );

  void _markRefreshFailed(String key) {
    setState(() {
      _refreshErrorKey = key;
      for (var day = 0; day < _dayErrors.length; day++) {
        if (jsonTimings[day].isEmpty || jsonDataDate[day].isEmpty) {
          _dayErrors[day] = true;
        }
      }
    });
  }

  Future<bool> _fetchPrayerTimes({bool forceRefresh = false}) async {
    if (!mounted) return false;
    setState(() {
      _isRefreshing = true;
      _refreshErrorKey = null;
    });
    var todayLoaded = false;
    final baseDate = prayerDate(DateTime.now());
    try {
      final savedLocation = await api_utils.getSavedLocation();
      if (!mounted) return false;
      if (savedLocation['error'] != '') {
        _markRefreshFailed('Location_Missing_Error');
        return false;
      }
      final identity = await helper.constructAPIParameters(
        '',
        helper.dateFormatter(baseDate),
        savedLocation,
        _prefs,
      );
      if (!mounted) return false;
      if (identity != _prayerDataIdentity) {
        setState(() {
          _prayerDataIdentity = identity;
          _loadedPrayerDate = baseDate;
          _prayerDays.clear();
          for (var day = 0; day < NUMBER_OF_DAYS; day++) {
            jsonTimings[day] = {};
            jsonDataDate[day] = {};
            _dayErrors[day] = false;
          }
          nextPrayTime = null;
          prayerMetadata = {};
          savedLocationAddress = helper.getAddressLocation(savedLocation);
        });
      }
      final missingDays = <int>[];
      // Populate all available cached days before waiting for the network.
      for (var day = 0; day < NUMBER_OF_DAYS; day++) {
        final cached = await api_utils.getDataFromDay(
          day,
          savedLocation,
          cacheOnly: true,
          baseDate: baseDate,
        );
        if (!mounted) return false;
        if (cached['error'] == '') {
          await _applyPrayerDay(
            day,
            cached['jsonData'],
            savedLocation,
            baseDate,
          );
          if (day == 0) {
            todayLoaded = true;
          }
          if (forceRefresh) missingDays.add(day);
        } else {
          missingDays.add(day);
        }
      }
      var success = true;
      for (final day in missingDays) {
        final result = await api_utils.getDataFromDay(
          day,
          savedLocation,
          baseDate: baseDate,
          forceRefresh: forceRefresh,
        );
        if (!mounted) return false;
        if (result['error'] != '') {
          // One failed request is enough to stop this attempt; cached pages
          // stay readable and the remaining missing pages get a retry state.
          _markRefreshFailed('Home_Refresh_Error');
          success = false;
          break;
        }
        await _applyPrayerDay(day, result['jsonData'], savedLocation, baseDate);
        if (day == 0) {
          todayLoaded = true;
        }
      }
      if (prayerDate(DateTime.now()) != baseDate) return false;
      final currentIdentity = await helper.constructAPIParameters(
        '',
        helper.dateFormatter(baseDate),
        await api_utils.getSavedLocation(),
        _prefs,
      );
      if (!mounted || currentIdentity != identity) return false;
      if (mounted && todayLoaded) {
        final configuration = prayerConfigurationIdentity(identity!);
        if (!kIsWeb && Platform.isAndroid) {
          await homewidget_utils.updateHomePage(
            _prayerDays.values.toList(),
            configuration,
          );
        }
        final scheduled = await helper.handleNotifications(
          _prefs,
          _prayerDays.values.toList(),
          configuration: configuration,
        );
        if (!scheduled && mounted) {
          _markRefreshFailed('Prayer_Notifications_Refresh_Error');
          success = false;
        }
        if (success) {
          await helper.updateLastFetchedDate(
            await _prefs,
            fetchedDate: baseDate,
          );
        }
      }
      return success;
    } catch (error, stack) {
      debugPrint('Prayer refresh failed: $error\n$stack');
      if (mounted) _markRefreshFailed('Home_Refresh_Error');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        if (nextPrayTime != null) resetTimer();
      }
    }
  }

  Future<void> _applyPrayerDay(
    int day,
    Map<String, dynamic> response,
    Map<String, dynamic> savedLocation,
    DateTime baseDate,
  ) async {
    final timings = Map<String, dynamic>.from(
      response['data']['timings'] as Map,
    );
    final dated = PrayerDay(
      prayerDate(baseDate, day),
      timings,
      dateData: Map<String, dynamic>.from(response['data']['date'] as Map),
    );
    final displayTimings = await api_utils.getTimings24System(dated.timings);
    if (!mounted || prayerDate(DateTime.now()) != baseDate) return;
    setState(() {
      _prayerDays[day] = dated;
      _updateNextPrayer();
      jsonDataDate[day] = Map<String, dynamic>.from(
        response['data']['date'] as Map,
      );
      jsonTimings[day] = displayTimings;
      _dayErrors[day] = false;
      savedLocationAddress = helper.getAddressLocation(savedLocation);
      if (day == 0) {
        prayerMetadata = response['data']['meta'] is Map
            ? Map<String, dynamic>.from(response['data']['meta'] as Map)
            : <String, dynamic>{};
      }
    });
  }

  // final pageController = PageController(viewportFraction: 0.8, keepPage: true);
  final daysListViewController = ScrollController();
  // final pages = List.generate(7, (index) => Container());

  Widget _buildAppVersionFooter() {
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        if (version == null || version.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Home_Panel_Version'.tr(namedArgs: {'version': version}),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.of(context).text.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDestination(AppDestination destination) async {
    if (destination == AppDestination.home) return;
    stopTimer();
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: RouteSettings(name: '/${destination.name}'),
          builder: (_) => destination.page(
            preferences: _prefs,
            prayerDays: _prayerDays.values.toList(),
          ),
        ),
      );
      if (!mounted) return;
      if (destination == AppDestination.settings ||
          destination == AppDestination.notifications) {
        await _refresh.runAfterCurrent(_fetchPrayerTimes);
      }
    } finally {
      if (mounted) startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      dialogStyle: UpgradeDialogStyle.cupertino,
      child: RefreshIndicator(
        onRefresh: () {
          return FetchAPI(forceRefresh: true);
        },
        child: Scaffold(
          backgroundColor: _styledWeb
              ? AppPalette.of(context).canvas
              : AppPalette.of(context).canvas,
          drawer: AppDrawer(
            showQiblah: !kIsWeb,
            showNotifications: !kIsWeb && Platform.isAndroid,
            footer: _buildAppVersionFooter(),
            onDestination: (destination) {
              Navigator.of(context).pop();
              unawaited(_openDestination(destination));
            },
            onShare: () {
              Navigator.of(context).pop();
              share_utils.shareApp();
            },
            onRate: () {
              Navigator.of(context).pop();
              unawaited(_openStoreListingForReview());
            },
          ),
          appBar: AppBar(
            backgroundColor: _styledWeb
                ? AppPalette.of(context).canvas
                : AppPalette.of(context).canvas,
            elevation: _styledWeb ? 0 : null,
            title: Text(
              widget.title.tr(),
              style: TextStyle(color: AppPalette.of(context).text),
            ),
            centerTitle: !_styledWeb,
            iconTheme: IconThemeData(color: AppPalette.of(context).text),
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
                    ? [
                        AppPalette.of(context).canvas,
                        AppPalette.of(context).panel,
                      ]
                    : [
                        AppPalette.of(context).canvas,
                        AppPalette.of(context).canvas,
                        AppPalette.of(context).canvas,
                        AppPalette.of(context).canvas,
                        AppPalette.of(context).panel,
                        AppPalette.of(context).canvas,
                        AppPalette.of(context).canvas,
                        AppPalette.of(context).canvas,
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

  Widget _buildHomeContent(PageController pageController) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AnimatedBuilder(
        animation: androidBackgroundSetup,
        builder: (context, _) => androidBackgroundSetup.failed
            ? RetryNotice(
                message: 'Home_Background_Setup_Error'.tr(),
                onRetry: androidBackgroundSetup.running
                    ? null
                    : () => androidBackgroundSetup.run(),
              )
            : const SizedBox.shrink(),
      ),
      if (_refreshErrorKey != null)
        RetryNotice(
          message: _refreshErrorKey!.tr(),
          onRetry: _isRefreshing ? null : () => FetchAPI(forceRefresh: true),
        ),
      if (_isRefreshing)
        LinearProgressIndicator(color: AppPalette.of(context).accent),
      _buildDashboard(pageController),
    ],
  );

  Widget _buildDashboard(PageController pageController) {
    final dashboard = HomeDashboardLayout(
      allowWideLayout: kIsWeb,
      stretchPanels: false,
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
          _buildReadingSection(),
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
                style: TextStyle(
                  color: AppPalette.of(context).accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Home_Web_Heading'.tr(),
                style: TextStyle(
                  color: AppPalette.of(context).text,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Home_Web_Description'.tr(),
                style: TextStyle(
                  color: AppPalette.of(context).muted,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Head for location
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                if (!_styledWeb) const SizedBox(width: 48),
                if (_styledWeb) ...[
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppPalette.of(context).accent,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: InkWell(
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        backgroundColor: AppPalette.of(context).panel,
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
                      child: Text(
                        savedLocationAddress,
                        style: _styledWeb
                            ? savedAddressLocationStyle.copyWith(fontSize: 20)
                            : savedAddressLocationStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Home_Panel_Settings'.tr(),
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
                          await _refresh.runAfterCurrent(_fetchPrayerTimes);
                        }
                      },
                      icon: Icon(
                        Icons.settings,
                        color: AppPalette.of(context).text,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          timeLeftWidget(),
          daysOfWeekWidget(pageController),
          _buildPrayerPager(pageController),
        ],
      ),
    );
  }

  Widget _buildPrayerPager(PageController pageController) {
    return ContentHeightPageView(
      key: const PageStorageKey('home_prayer_pager'),
      controller: pageController,
      itemCount: 7,
      itemBuilder: (_, index) {
        if (jsonTimings[index].isEmpty || jsonDataDate[index].isEmpty) {
          if (_dayErrors[index]) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: RetryNotice(
                message: 'Home_Day_Unavailable'.tr(),
                onRetry: _isRefreshing
                    ? null
                    : () => FetchAPI(forceRefresh: true),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
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
          ? TextStyle(
              color: AppPalette.of(context).muted,
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
        titleKey: 'Prophets_Title',
        assetPath: prophetsHomeIcon,
        onTap: _openProphetsPage,
      ),
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

  Future<void> _openProphetsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProphetsPage()),
    );
  }

  Future<void> _openDailyRoutinePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DailyRoutinePageClass(prayerDays: _prayerDays.values.toList()),
      ),
    );
  }

  Widget timeLeftWidget() {
    if (nextPrayTime == null) return const SizedBox.shrink();
    final index = _prayerDays.entries
        .where((entry) => entry.value.date == prayerDate(nextPrayTime!))
        .firstOrNull
        ?.key;
    return PrayerCountdown(
      name: nextPray,
      time: nextPrayTime!,
      displayTime: index == null
          ? '-'
          : jsonTimings[index][nextPray]?.toString() ?? '-',
      clock: _clock,
    );
  }

  Widget daysOfWeekWidget(PageController pageController) {
    return SizedBox(
      height: 72 * MediaQuery.textScalerOf(context).scale(14) / 14,
      child: ListView.builder(
        key: const ValueKey("days_of_week"),
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
        width:
            (_styledWeb ? 56 : 76) *
            MediaQuery.textScalerOf(context).scale(14) /
            14,
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        padding: _styledWeb
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? null
              : _styledWeb
              ? Colors.transparent
              : AppPalette.of(context).canvas.withOpacity(0.7),
          gradient: isSelected
              ? AppPalette.of(context).highlightGradient
              : null,
          borderRadius: BorderRadius.circular(15.0),
          border: Border.all(
            color: _styledWeb
                ? (isSelected
                      ? AppPalette.of(context).accent.withValues(alpha: .4)
                      : Colors.transparent)
                : (isSelected
                      ? AppPalette.of(context).accent.withValues(alpha: .25)
                      : AppPalette.of(context).canvas),
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
            Text(
              dayText,
              style: TextStyle(
                fontSize: _styledWeb ? 11 : null,
                color: _styledWeb
                    ? (isSelected
                          ? AppPalette.of(context).accent
                          : AppPalette.of(context).muted)
                    : (isSelected
                          ? AppPalette.of(context).text
                          : AppPalette.of(context).text),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              dayNumberText,
              style: TextStyle(
                fontSize: _styledWeb ? 13 : null,
                color: isSelected
                    ? AppPalette.of(context).text
                    : AppPalette.of(context).text.withOpacity(0.8),
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
    final date = jsonDataDate[daynumber];
    return Padding(
      key: ValueKey('prayer_timing_page_$daynumber'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrayerDateHeader(
            gregorian: _prayerDays[daynumber]!.date,
            hijri: Map<String, dynamic>.from(date['hijri'] as Map),
            onMonthsHelp: () => showDialog<void>(
              context: context,
              builder: (context) => prayer_calendar_model.showdialog(context),
            ),
          ),
          ..._prayerRows(daynumber),
        ],
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

  Widget detailsRow(String headText, String detailsText, int dayNumber) =>
      PrayerTimeRow(
        dense: true,
        label: headText.tr(),
        time: detailsText,
        selected: nextPray == headText && _isNextPrayerOnDay(dayNumber),
      );

  bool _isNextPrayerOnDay(int day) =>
      nextPrayTime != null &&
      _prayerDays[day]?.date == prayerDate(nextPrayTime!);

  void _updateNextPrayer() {
    final next = nextPrayerOccurrence(_prayerDays.values, DateTime.now());
    nextPray = next?.name ?? '';
    nextPrayTime = next?.time;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(FetchAPI(automatic: true));
    }
  }

  void startTimer() {
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(refreshDuration, (_) {
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final oldName = nextPray;
      final oldTime = nextPrayTime;
      _updateNextPrayer();
      _clock.value = DateTime.now();
      if (oldName != nextPray || oldTime != nextPrayTime) setState(() {});
      final needsData =
          _loadedPrayerDate != prayerDate(DateTime.now()) ||
          _dayErrors.any((failed) => failed);
      if (needsData && _refresh.canRefreshAutomatically) {
        unawaited(FetchAPI(automatic: true));
      }
    });
  }

  void stopTimer() {
    refreshTimer?.cancel();
    refreshTimer = null;
  }

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
            border: Border.all(color: AppPalette.of(context).border),
            color: AppPalette.of(context).canvas,
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
