import 'package:dropdown_search/dropdown_search.dart';
import 'package:muslim/home_page.dart';
import 'package:muslim/UI/quiz/quiz_page.dart';
import 'package:muslim/UI/mosque/nearest_mosque_page.dart';
import 'package:muslim/UI/prayer_notifications/prayer_notifications.dart';
import 'package:muslim/utils/quiz_utils.dart';
import 'package:muslim/utils/helper.dart' as helper;
import 'package:muslim/shared/constants.dart' as constants;
import 'package:package_info_plus/package_info_plus.dart';
import 'prayer_times_cache_test.dart' show validPrayerTimesResponse;
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:muslim/main.dart';
import 'package:muslim/shared/app_appearance.dart';
import 'package:muslim/shared/app_navigation.dart';
import 'package:muslim/shared/app_status.dart';
import 'package:muslim/shared/app_theme.dart';
import 'package:muslim/shared/appearance_picker.dart';
import 'package:muslim/shared/home_action_grid.dart';
import 'package:muslim/shared/number_field.dart';
import 'package:muslim/shared/prayer_time_row.dart';
import 'package:muslim/shared/prayer_date_header.dart';
import 'package:muslim/shared/content_height_page_view.dart';
import 'package:muslim/shared/responsive_web_layout.dart';
import 'package:muslim/shared/web_home_style.dart';
import 'package:muslim/UI/qiblah/qiblah_compass.dart';
import 'package:flutter_qiblah_advanced/flutter_qiblah_advanced.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:muslim/UI/biographies/biography_page.dart';
import 'package:muslim/UI/contact/contact.dart';
import 'package:muslim/UI/daily_routine/daily_routine_page.dart';
import 'package:muslim/UI/hadith/main_page.dart';
import 'package:muslim/UI/hadith/quick_hadith_card.dart';
import 'package:muslim/UI/month/months_page.dart';
import 'package:muslim/UI/prayer_metadata_sheet.dart';
import 'package:muslim/UI/prophets/prophets_page.dart';
import 'package:muslim/UI/qiblah/qiblah_page.dart';
import 'package:muslim/UI/quran/quran_page.dart';
import 'package:muslim/UI/radio/radio_page.dart';
import 'package:muslim/UI/settings/settings.dart';
import 'package:muslim/utils/hadith_utils.dart';
import 'package:muslim/utils/prayer_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(
            File('$path/${locale.toLanguageTag()}.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
}

Future<AppAppearance> _pump(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('en', 'US'),
  Brightness brightness = Brightness.light,
  double width = 320,
  double height = 1000,
  double scale = 2,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'app_theme_mode',
    brightness == Brightness.dark ? 'dark' : 'light',
  );
  final appearance = AppAppearance(prefs);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
      startLocale: locale,
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _Loader(),
      child: MyApp(appearance: appearance, home: home),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await EasyLoading.dismiss(animation: false);
    await tester.pumpWidget(const SizedBox.shrink());
    appearance.dispose();
  });
  return appearance;
}

PrayerDay _day(int offset) => PrayerDay(DateTime(2026, 10, 7 + offset), {
  'Fajr': '05:00',
  'Sunrise': '06:30',
  'Dhuhr': '12:10',
  'Asr': '15:30',
  'Maghrib': '18:00',
  'Isha': '19:20',
});

Future<void> _seedHomePrayers() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('inAppReviewSubmitted', true);
  final location =
      jsonDecode(prefs.getString('location')!) as Map<String, dynamic>;
  for (var offset = 0; offset < 7; offset++) {
    final date = prayerDate(DateTime.now(), offset);
    final response = validPrayerTimesResponse();
    response['data']['date']['gregorian'] = {
      'date': helper.dateFormatter(date),
      'month': {'en': 'October'},
    };
    response['data']['date']['hijri'] = {
      'date': '${27 + offset}-04-1448',
      'month': {'en': 'Rabi al-Thani'},
    };
    final key = (await helper.constructAPIParameters(
      '',
      helper.dateFormatter(date),
      location,
      Future.value(prefs),
    ))!;
    await prefs.setString(
      helper.prayerTimesCacheKey(key),
      jsonEncode(response),
    );
  }
}

void _expectCompletePrayerCard(WidgetTester tester, int index) {
  final pager = find.byKey(const PageStorageKey('home_prayer_pager'));
  final card = find.byKey(ValueKey('prayer_timing_page_$index'));
  final rows = find.descendant(of: card, matching: find.byType(PrayerTimeRow));
  final date = find.descendant(
    of: card,
    matching: find.byType(PrayerDateHeader),
  );
  expect(rows, findsNWidgets(6));
  expect(date, findsOneWidget);
  final bounds = tester.getRect(pager);
  expect(tester.getRect(date).top, greaterThanOrEqualTo(bounds.top));
  expect(tester.getRect(rows.last).bottom, lessThanOrEqualTo(bounds.bottom));
  final scrollables = tester.widgetList<Scrollable>(
    find.descendant(of: pager, matching: find.byType(Scrollable)),
  );
  expect(scrollables, isNotEmpty);
  expect(
    scrollables.every(
      (s) => axisDirectionToAxis(s.axisDirection) == Axis.horizontal,
    ),
    isTrue,
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'Muslim',
      packageName: 'com.bplusplus.muslim',
      version: '2.19.0',
      buildNumber: '74',
      buildSignature: 'test',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return null;
      },
    );
  });
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'location': jsonEncode({
        'type': 'address',
        'location': 'London, United Kingdom',
        'cityCountry': 'London, United Kingdom',
        'latitude': 51.5074,
        'longitude': -0.1278,
      }),
    }),
  );

  test(
    'appearance persists and invalid stored choices use the device theme',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', 'old-invalid-value');
      final appearance = AppAppearance(prefs);
      expect(appearance.mode, ThemeMode.system);
      expect(await appearance.setMode(ThemeMode.dark), isTrue);
      expect(AppAppearance(prefs).mode, ThemeMode.dark);
      expect(await appearance.setMode(ThemeMode.system), isTrue);
      expect(prefs.getString('app_theme_mode'), 'system');
      appearance.dispose();
    },
  );

  test(
    'translated navigation and new controls have matching bilingual keys',
    () {
      final en =
          jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
              as Map;
      final ar =
          jsonDecode(File('assets/translations/ar-EG.json').readAsStringSync())
              as Map;
      expect(ar.keys.toSet(), en.keys.toSet());
      for (final key in [
        for (final destination in AppDestination.values) destination.titleKey,
        'Navigation_Daily',
        'Navigation_Read',
        'Navigation_Tools',
        'Navigation_App',
        'Appearance_Title',
        'Appearance_system',
        'Appearance_dark',
        'Appearance_light',
        'Audio_Preview',
        'Audio_Stop',
        'Daily_Routine_Details',
      ]) {
        expect(en[key], isNotEmpty, reason: key);
        expect(ar[key], matches(RegExp(r'[\u0600-\u06ff]')), reason: key);
      }
    },
  );

  for (final brightness in Brightness.values) {
    test(
      'text, muted text and accent meet normal-text contrast in $brightness',
      () {
        final colors = AppPalette(AppTheme.build(brightness).colorScheme);
        double contrast(Color a, Color b) {
          final x = a.computeLuminance();
          final y = b.computeLuminance();
          return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
        }

        for (final background in [
          colors.canvas,
          colors.panel,
          colors.accentSurface,
        ]) {
          for (final foreground in [colors.text, colors.muted, colors.accent]) {
            expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
          }
        }
      },
    );
  }

  testWidgets(
    'appearance switches immediately and root preserves inherited scaling',
    (tester) async {
      final appearance = await _pump(
        tester,
        const Scaffold(body: SingleChildScrollView(child: AppearancePicker())),
      );
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(AppearancePicker)),
        ).scale(10),
        20,
      );
      await tester.tap(find.byKey(const ValueKey('appearance-dark')));
      await tester.pumpAndSettle();
      expect(appearance.mode, ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(AppearancePicker))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'number controls enforce minimum, label buttons, and preserve typed values',
    (tester) async {
      final controller = TextEditingController(text: '-100');
      addTearDown(controller.dispose);
      final values = <int>[];
      await _pump(
        tester,
        Scaffold(
          body: AppNumberField(
            controller: controller,
            label: 'Fajr',
            onChanged: values.add,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Decrease Fajr'));
      expect(controller.text, '-100');
      expect(values, isEmpty);
      await tester.tap(find.byTooltip('Increase Fajr'));
      expect(controller.text, '-99');
      await tester.enterText(find.byType(TextField), '-15');
      expect(values, [-99, -15]);
      expect(
        tester.getSize(find.byType(IconButton).first).shortestSide,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'drawer closes before routing and Back returns to the usable home',
    (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Home')),
            drawer: AppDrawer(
              showQiblah: false,
              showNotifications: false,
              footer: const Text('Version 2.19.0'),
              onShare: () {},
              onRate: () {},
              onDestination: (destination) {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Destination')),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-qiblah')), findsNothing);
      expect(find.byKey(const ValueKey('home-notifications')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home-routine')));
      await tester.pumpAndSettle();
      expect(find.text('Destination'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shortcut can be focused and activated by keyboard', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: HomeActionGrid(
            compact: false,
            children: [
              HomeActionTile(
                title: 'Nearest mosque',
                assetPath: 'assets/mosque/mosque_home.png',
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home unavailable-day retry stays readable at 3x text', (
    tester,
  ) async {
    await _pump(
      tester,
      MyHomePage(title: 'App_Title', loadHadith: () async => null),
      scale: 3,
    );
    expect(find.byType(AppStatus), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Settings dropdown and prayer adjustment preserve readable controls',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await _pump(tester, SettingsPageClass(prefs: Future.value(prefs)));
      await tester.ensureVisible(find.byType(DropdownSearch<String>).first);
      await tester.tap(find.byType(DropdownSearch<String>).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(SettingsPageClass))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const PageStorageKey('settings_advanced')),
      );
      await tester.tap(find.text('Settings_Advanced'.tr()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('tune_input_Fajr')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byTooltip('Increase Fajr'));
      await tester.tap(find.byTooltip('Increase Fajr'));
      await tester.pumpAndSettle();
      expect(prefs.getInt(constants.prayerTunePreferenceKey('Fajr')), 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Home dates and Isha fit together at normal text in $locale $brightness',
        (tester) async {
          await _seedHomePrayers();
          await _pump(
            tester,
            MyHomePage(title: 'App_Title', loadHadith: () async => null),
            locale: locale,
            brightness: brightness,
            width: 393,
            height: 850,
            scale: 1,
          );
          _expectCompletePrayerCard(tester, 0);
          final pager = find.byKey(const PageStorageKey('home_prayer_pager'));
          expect(tester.getRect(pager).bottom, lessThan(850));
          final header = find.descendant(
            of: find.byKey(const ValueKey('prayer_timing_page_0')),
            matching: find.byType(PrayerDateHeader),
          );
          expect(
            find.descendant(
              of: header,
              matching: find.text('27 ${'Rabi al-Thani'.tr()} 1448'),
            ),
            findsOneWidget,
          );
          final help = find.descendant(
            of: header,
            matching: find.byType(IconButton),
          );
          expect(tester.getSize(help).height, greaterThanOrEqualTo(48));
          await tester.tap(help);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          Navigator.of(tester.element(find.byType(Dialog))).pop();
          await tester.pumpAndSettle();
          await tester.drag(
            pager,
            const Offset(-300, 0) * (locale.languageCode == 'ar' ? -1 : 1),
          );
          await tester.pumpAndSettle();
          _expectCompletePrayerCard(tester, 1);
          final tomorrow = tester.widget<PrayerDateHeader>(
            find.descendant(
              of: find.byKey(const ValueKey('prayer_timing_page_1')),
              matching: find.byType(PrayerDateHeader),
            ),
          );
          expect(tomorrow.gregorian, prayerDate(DateTime.now(), 1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('live compass dial is readable in $brightness', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: QiblahCompassWidget(
            directions: () =>
                Stream.value(const QiblahDirection(118.6, 0, 118.6, 1)),
          ),
        ),
        brightness: brightness,
        width: 393,
        scale: 1,
      );
      final pictures = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .toList();
      expect(pictures, hasLength(2));
      final dial = pictures.first.bytesLoader as SvgAssetLoader;
      final needle = pictures.last.bytesLoader as SvgAssetLoader;
      final palette = AppPalette.of(
        tester.element(find.byType(QiblahCompassWidget)),
      );
      expect(dial.theme!.currentColor, palette.text);
      final textLuminance = palette.text.computeLuminance();
      final backgroundLuminance = palette.canvas.computeLuminance();
      final contrast = (textLuminance > backgroundLuminance)
          ? (textLuminance + .05) / (backgroundLuminance + .05)
          : (backgroundLuminance + .05) / (textLuminance + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
      expect(needle.theme, isNull);
      expect(
        File('assets/qiblah/compass.svg').readAsStringSync(),
        contains('fill="currentColor"'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'content pager remeasures after text scaling in the wide dashboard',
    (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      Widget dashboard() => Scaffold(
        body: SingleChildScrollView(
          child: HomeDashboardLayout(
            allowWideLayout: true,
            stretchPanels: false,
            prayerPanel: WebPrayerPanel(
              styled: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ContentHeightPageView(
                    key: const ValueKey('adaptive_pager'),
                    controller: controller,
                    itemCount: 1,
                    itemBuilder: (context, index) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PrayerDateHeader(
                          gregorian: DateTime(2026, 10, 8),
                          hijri: const {'date': '27-04-1448'},
                          onMonthsHelp: () {},
                        ),
                        for (final name in [
                          'Fajr',
                          'Sunrise',
                          'Dhuhr',
                          'Asr',
                          'Maghrib',
                          'Isha',
                        ])
                          PrayerTimeRow(
                            label: name.tr(),
                            time: '19:30',
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            contentPanel: const SizedBox(height: 900),
          ),
        ),
      );
      final appearance = await _pump(
        tester,
        dashboard(),
        width: 1100,
        scale: 3,
      );
      final pager = find.byKey(const ValueKey('adaptive_pager'));
      final largeHeight = tester.getSize(pager).height;
      final isha = find.byType(PrayerTimeRow).last;
      expect(
        tester.getRect(isha).bottom,
        lessThanOrEqualTo(tester.getRect(pager).bottom),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await tester.pumpAndSettle();
      expect(tester.getSize(pager).height, lessThan(largeHeight));
      expect(
        tester.getRect(isha).bottom,
        lessThanOrEqualTo(tester.getRect(pager).bottom),
      );
      expect(tester.takeException(), isNull);
      // Keep the appearance object referenced until the tree is disposed.
      expect(appearance.mode, ThemeMode.light);
    },
  );

  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    testWidgets('Home navigation and cached prayers at 3x text in $locale', (
      tester,
    ) async {
      await _seedHomePrayers();
      await _pump(
        tester,
        MyHomePage(title: 'App_Title', loadHadith: () async => null),
        locale: locale,
        scale: 3,
      );
      _expectCompletePrayerCard(tester, 0);
      expect(tester.takeException(), isNull);
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-home')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home-quran')),
        400,
        scrollable: find
            .descendant(
              of: find.byType(AppDrawer),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('home-quran')));
      await tester.pumpAndSettle();
      expect(find.byType(QuranPageClass), findsOneWidget);
      Navigator.of(tester.element(find.byType(QuranPageClass))).pop();
      await tester.pumpAndSettle();
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('notification modes and sounds fit at 3x text in $locale', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prayerNotification', true);
      await prefs.setBool('prayerNotification_Fajr', true);
      for (final name in constants.PRAYER_NOTIFICATION_NAMES) {
        await prefs.setBool('prayerNotification_$name', true);
        await prefs.setString(
          constants.prayerNotificationModePreferenceKey(name),
          constants.prayerNotificationModeCustomSound,
        );
      }
      await _pump(
        tester,
        PrayerNotificationsPageClass(prefs: Future.value(prefs)),
        locale: locale,
        scale: 3,
      );
      final tile = find.byKey(const PageStorageKey('prayer_options_Fajr'));
      await tester.ensureVisible(tile);
      await tester.tap(
        find.descendant(of: tile, matching: find.text('Fajr'.tr())).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 1100.0]) {
        final label = '$locale / $brightness / $width / 2x text';
        testWidgets('shared controls fit $label', (tester) async {
          await _pump(
            tester,
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AppStatus(
                      message: 'Home_Day_Unavailable'.tr(),
                      actionLabel: 'Reload'.tr(),
                      onAction: () {},
                    ),
                    PrayerTimeRow(
                      label: 'Fajr'.tr(),
                      time: '05:12 AM',
                      selected: true,
                    ),
                    HomeActionGrid(
                      compact: width > 600,
                      children: [
                        HomeActionTile(
                          title: 'Home_Utilities_Find_Nearest_Mosque'.tr(),
                          assetPath: 'assets/mosque/mosque_home.png',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            locale: locale,
            brightness: brightness,
            width: width,
          );
          expect(tester.takeException(), isNull);
          final clock = tester.widget<Text>(find.text('05:12 AM'));
          expect(clock.textDirection, TextDirection.ltr);
        });

        final screens = <String, Widget Function()>{
          'Quiz': () => QuizPageClass(
            loadQuestion: () async => const QuizQuestion(
              id: 'test',
              category: 'Daily practice',
              question: 'Select an answer',
              type: QuizQuestionType.singleSelection,
              options: ['Answer A', 'Answer B'],
              answers: ['Answer A'],
            ),
          ),
          'Mosques unavailable': () => NearestMosquePageClass(
            loadSearch: (_) async => throw StateError('offline'),
          ),
          'Quran': () => const QuranPageClass(),
          'Hadith': () => const HadithHomePageClass(),
          'Qiblah unavailable': () =>
              QiblahClass(sensorSupport: () async => false),
          'Contact': () => const ContactPageClass(),
          'Biography': () => const BiographyPage(),
          'Prophets': () => const ProphetsPage(),
          'Radio': () => const RadioPageClass(),
          'Settings': () =>
              SettingsPageClass(prefs: SharedPreferences.getInstance()),
          'Calendar': () => MonthsPageClass(
            loadMonth: (month) async => [
              DetailedDates(
                'Mon',
                '1-10',
                '20-4',
                '05:00',
                '06:30',
                '12:10',
                '15:30',
                '18:00',
                '19:20',
                '01-${month.month.toString().padLeft(2, '0')}-${month.year}',
              ),
            ],
          ),
          'Daily routine': () => DailyRoutinePageClass(
            now: () => DateTime(2026, 10, 7, 12),
            prayerDays: [_day(-1), _day(0), _day(1)],
            loadDay: (_) async => null,
          ),
          'Hadith card': () => const Scaffold(
            body: SingleChildScrollView(
              child: QuickHadithCardPageClass(
                hadith: RandomHadith(hadith: 'الحمد لله رب العالمين'),
              ),
            ),
          ),
          'Calculation sheet': () => const Scaffold(
            body: PrayerMetadataSheet(
              locationName: 'London, United Kingdom',
              metadata: {
                'timezone': 'Europe/London',
                'school': 'STANDARD',
                'midnightMode': 'STANDARD',
                'latitudeAdjustmentMethod': 'ANGLE_BASED',
                'polarCircleResolution': 'Unresolved',
                'polarReferenceLatitude': 48.5,
                'params': {'Fajr': 18.0, 'Isha': 17.0},
                'latitude': 51.5074,
                'longitude': -.1278,
                'method': {'name': 'Muslim World League', 'id': 3},
              },
            ),
          ),
        };
        for (final screen in screens.entries) {
          testWidgets('${screen.key} fits $label', (tester) async {
            await _pump(
              tester,
              screen.value(),
              locale: locale,
              brightness: brightness,
              width: width,
            );
            expect(tester.takeException(), isNull);
            expect(
              Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
              brightness,
            );
          });
        }
      }
    }
  }
}
