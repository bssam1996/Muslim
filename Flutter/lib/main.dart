
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:muslim/home_page.dart';
import 'package:muslim/utils/helper.dart';
import 'package:muslim/shared/constants.dart' as constants;
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MyApp());
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
      ),
      home: const MyHomePage(title: 'Muslim guide'),
      builder: EasyLoading.init(),
      localizationsDelegates: const [
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        MonthYearPickerLocalizations.delegate,
      ],
    );
  }
}


