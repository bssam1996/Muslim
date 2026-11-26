import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/shared/widget_appearance_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  String? stored;
  bool saveFails = false;
  final updates = <String>[];

  setUp(() async {
    stored = null;
    saveFails = false;
    updates.clear();
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
    await EasyLocalization.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          switch (call.method) {
            case 'getWidgetData':
              return stored;
            case 'saveWidgetData':
              if (saveFails) return false;
              expect(args['id'], widgetThemeModeKey);
              stored = args['data'] as String;
              return true;
            case 'updateWidget':
              updates.add(args['android'] as String);
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: WidgetAppearancePicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ThemeMode? selected(WidgetTester tester) => tester
      .widget<RadioGroup<ThemeMode>>(find.byType(RadioGroup<ThemeMode>))
      .groupValue;

  testWidgets(
    'defaults to system independently of the app and restores choice',
    (tester) async {
      await pumpPicker(tester);
      expect(selected(tester), ThemeMode.system);
      await tester.tap(find.byKey(const ValueKey('widget-appearance-light')));
      await tester.pumpAndSettle();
      expect(selected(tester), ThemeMode.light);
      expect(stored, 'light');
      expect(
        (await SharedPreferences.getInstance()).getString('app_theme_mode'),
        'dark',
      );
      // Widget refresh is Android-only; Flutter tests run on the host platform.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPicker(tester);
      expect(selected(tester), ThemeMode.light);
      await tester.tap(find.byKey(const ValueKey('widget-appearance-system')));
      await tester.pumpAndSettle();
      expect(stored, 'system');
    },
  );

  testWidgets('failed saves keep the previous selection', (tester) async {
    stored = 'dark';
    saveFails = true;
    await pumpPicker(tester);
    await tester.tap(find.byKey(const ValueKey('widget-appearance-light')));
    await tester.pumpAndSettle();
    expect(selected(tester), ThemeMode.dark);
    expect(stored, 'dark');
    expect(find.text('Settings_Unable_To_Save'), findsOneWidget);
    expect(updates, isEmpty);
  });

  testWidgets('unknown stored themes fall back to system', (tester) async {
    stored = 'invalid';
    await pumpPicker(tester);
    expect(selected(tester), ThemeMode.system);
  });

  test('widget labels are provided in both languages', () {
    for (final locale in ['en-US', 'ar-EG']) {
      final translations =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final key in [
        'Widget_Appearance_Title',
        'Widget_Appearance_Description',
        'Widget_Appearance_Retry',
      ]) {
        expect(translations[key], isNotEmpty);
        if (locale == 'ar-EG') {
          expect(translations[key], matches(RegExp(r'[\u0600-\u06ff]')));
        }
      }
    }
  });
}
