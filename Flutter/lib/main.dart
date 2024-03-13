import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:muslim/home_page.dart';
import 'package:muslim/shared/constants.dart';
import 'package:muslim/utils/helper.dart';
import 'package:muslim/shared/constants.dart' as constants;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:easy_localization/easy_localization.dart';
// import 'dart:io' show Platform;

void main() async{
  // runApp(DevicePreview(
  //   enabled: true,
  //   builder: (BuildContext context) => const MyApp(),
  // ));

  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
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
