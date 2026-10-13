import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:muslim/home_page.dart';
import 'package:muslim/shared/app_appearance.dart';
import 'package:muslim/shared/app_theme.dart';
import 'package:muslim/shared/responsive_web_layout.dart';
import 'package:muslim/utils/api_utils.dart' as api_utils;
import 'package:muslim/shared/constants.dart' as constants;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:muslim/utils/shared_preference_methods.dart'
    as shared_preference_methods;
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/android_startup.dart';

// import 'dart:io' show Platform;

void main() async {
  // runApp(DevicePreview(
  //   enabled: true,
  //   builder: (BuildContext context) => const MyApp(),
  // ));

  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );

  await shared_preference_methods.cleanupOldPrayerTimesData(
    SharedPreferences.getInstance(),
  );
  await api_utils.cleanupInvalidPrayerTimesData(
    SharedPreferences.getInstance(),
  );
  await shared_preference_methods.cleanupOldDailyRoutineData(
    SharedPreferences.getInstance(),
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: MyApp(
        appearance: AppAppearance(await SharedPreferences.getInstance()),
      ),
    ),
  );
  if (!kIsWeb && Platform.isAndroid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(androidBackgroundSetup.run());
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.appearance, this.home});
  final AppAppearance appearance;
  final Widget? home;
  @override
  Widget build(BuildContext context) {
    return AppAppearanceScope(
      appearance: appearance,
      child: AnimatedBuilder(
        animation: appearance,
        builder: (context, _) => MaterialApp(
          title: constants.gloabalAppName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(Brightness.light),
          darkTheme: AppTheme.build(Brightness.dark),
          themeMode: appearance.mode,
          home: home ?? const MyHomePage(title: 'App_Title'),
          // builder: EasyLoading.init(),
          builder: EasyLoading.init(
            builder: (context, child) {
              return kIsWeb ? ResponsiveWebViewport(child: child!) : child!;
            },
          ),
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          // localizationsDelegates: context.localizationDelegates
          localizationsDelegates: [
            GlobalWidgetsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            MonthYearPickerLocalizations.delegate,
            ...context.localizationDelegates,
          ],
        ),
      ),
    );
  }
}
