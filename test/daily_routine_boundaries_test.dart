import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/daily_routine/daily_routine_page.dart';
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

class _Host extends StatelessWidget {
  const _Host(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: context.locale,
    supportedLocales: context.supportedLocales,
    localizationsDelegates: context.localizationDelegates,
    home: child,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
      startLocale: const Locale('en', 'US'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _Loader(),
      child: _Host(child),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
}

PrayerDay _day(int day, String fajr) => PrayerDay(DateTime(2026, 10, day), {
  'Fajr': fajr,
  'Sunrise': '06:20',
  'Dhuhr': '12:10',
  'Asr': '15:30',
  'Maghrib': '18:00',
  'Isha': '19:20',
});

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'before dawn routine restores yesterday and closes at today Fajr',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'dailyRoutine/2026-10-06/wakeup_dua': true,
      });
      await _pump(
        tester,
        DailyRoutinePageClass(
          now: () => DateTime(2026, 10, 7, 4),
          prayerDays: [_day(6, '04:50'), _day(7, '05:00'), _day(8, '05:12')],
        ),
      );
      expect(find.text('Oct 6, 2026 · Fajr 04:50 to 05:00'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Fajr rollover selects new day without deleting previous completion',
    (tester) async {
      var now = DateTime(2026, 10, 7, 4);
      SharedPreferences.setMockInitialValues({
        'dailyRoutine/2026-10-06/wakeup_dua': true,
      });
      await _pump(
        tester,
        DailyRoutinePageClass(
          now: () => now,
          prayerDays: [_day(6, '04:50'), _day(7, '05:00'), _day(8, '05:12')],
        ),
      );
      now = DateTime(2026, 10, 7, 5, 0, 2);
      await tester.pump(const Duration(hours: 1, seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Oct 7, 2026 · Fajr 05:00 to 05:12'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isFalse,
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dailyRoutine/2026-10-06/wakeup_dua'), isTrue);
      expect(prefs.getBool('dailyRoutine/2026-10-07/wakeup_dua'), isTrue);
    },
  );

  testWidgets('routine rapid toggles persist final user choice', (
    tester,
  ) async {
    await _pump(
      tester,
      DailyRoutinePageClass(
        now: () => DateTime(2026, 10, 7, 8),
        prayerDays: [_day(7, '05:00'), _day(8, '05:12')],
      ),
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dailyRoutine/2026-10-07/wakeup_dua'), isFalse);
  });

  testWidgets('missing prayer data is visibly estimated and can recover', (
    tester,
  ) async {
    var available = false;
    await _pump(
      tester,
      DailyRoutinePageClass(
        now: () => DateTime(2026, 10, 7, 8),
        loadDay: (date) async => available
            ? _day(date.day, date.day == 8 ? '05:12' : '05:00')
            : null,
      ),
    );
    expect(find.textContaining('estimated times'), findsOneWidget);
    expect(find.text('Oct 7, 2026 · Fajr - to -'), findsOneWidget);
    available = true;
    await tester.tap(find.text('Reload'));
    await tester.pumpAndSettle();
    expect(find.textContaining('estimated times'), findsNothing);
    expect(find.text('Oct 7, 2026 · Fajr 05:00 to 05:12'), findsOneWidget);
  });

  testWidgets('resume recalculates midnight without inventing the next Fajr', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 7, 23);
    await _pump(
      tester,
      DailyRoutinePageClass(
        now: () => now,
        prayerDays: [_day(7, '05:00'), _day(8, '05:12')],
        loadDay: (_) async => null,
      ),
    );
    now = DateTime(2026, 10, 8, 0, 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Oct 7, 2026 · Fajr 05:00 to 05:12'), findsOneWidget);
    expect(find.textContaining('estimated times'), findsNothing);
  });
}
