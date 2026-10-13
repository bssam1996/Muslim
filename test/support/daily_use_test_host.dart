import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:muslim/main.dart';
import 'package:muslim/shared/app_appearance.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyUseAssetLoader extends AssetLoader {
  const DailyUseAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(
            File('$path/${locale.toLanguageTag()}.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
}

Future<AppAppearance> pumpDailyPage(
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
      assetLoader: const DailyUseAssetLoader(),
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

void initializeDailyUseTests() {
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
      '24system': true,
      'inAppReviewSubmitted': true,
    }),
  );
}
