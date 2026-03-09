import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:muslim/home_page.dart';
import 'package:muslim/shared/constants.dart';
import 'package:muslim/utils/helper.dart';
import 'package:muslim/shared/constants.dart' as constants;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:muslim/utils/homewidget_utils.dart' as homewidget_utils;
import 'package:workmanager/workmanager.dart' as workmanager;

// import 'dart:io' show Platform;

Future<void> _configureAndroidBackgroundTasks() async {
  await workmanager.Workmanager()
      .initialize(homewidget_utils.workManagerCallbackDispatcher);
  // Cleanup the legacy periodic worker name used by older app versions.
  await workmanager.Workmanager().cancelByUniqueName("Muslim");
  await workmanager.Workmanager().registerPeriodicTask(
    homewidget_utils.dailyRefreshUniqueName,
    homewidget_utils.dailyRefreshTaskName,
    frequency: const Duration(hours: 6),
    constraints: workmanager.Constraints(
      networkType: workmanager.NetworkType.connected,
    ),
    existingWorkPolicy: workmanager.ExistingPeriodicWorkPolicy.update,
  );
}

void main() async {
  // runApp(DevicePreview(
  //   enabled: true,
  //   builder: (BuildContext context) => const MyApp(),
  // ));

  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (!kIsWeb && Platform.isAndroid) {
    await _configureAndroidBackgroundTasks();
  }

  runApp(EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: const MyApp()
  ),);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const primaryColor = constants.primaryColor;
    MaterialColor materialColor = getMaterialColor(primaryColor);
    return MaterialApp(
      title: constants.gloabalAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: materialColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        primaryColor: primaryColor,
        textTheme: const TextTheme(
          titleMedium: TextStyle(color: textColor),
          titleSmall: TextStyle(color: textColor),

        ),
        useMaterial3: false,
      ),
      home: const MyHomePage(title: 'App_Title'),
      // builder: EasyLoading.init(),
      builder: EasyLoading.init(builder: (context, child){
        return MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)), child: child!);
      }),
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      // localizationsDelegates: context.localizationDelegates
      localizationsDelegates: [
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        MonthYearPickerLocalizations.delegate,
        ...context.localizationDelegates,
      ],
    );
  }
}

