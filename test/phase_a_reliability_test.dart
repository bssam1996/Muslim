import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qiblah_advanced/flutter_qiblah_advanced.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim/UI/hadith/customsearch/custom_search.dart';
import 'package:muslim/UI/month/months_page.dart';
import 'package:muslim/UI/qiblah/qiblah_compass.dart';
import 'package:muslim/UI/qiblah/qiblah_page.dart';
import 'package:muslim/shared/loading_indicator.dart';
import 'package:muslim/utils/android_startup.dart';
import 'package:muslim/utils/api_utils.dart' as api;
import 'package:muslim/utils/hadith_utils.dart';
import 'package:muslim/utils/helper.dart' as helper;
import 'package:muslim/utils/refresh_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_times_cache_test.dart' show validPrayerTimesResponse;

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
  // Unresolved requests can animate indefinitely; only advance initialization.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

String _label(String key) =>
    (jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
            as Map<String, dynamic>)[key]
        as String;

DetailedDates _day(DateTime month, String fajr) => DetailedDates(
  'Mon',
  '01-${month.month}',
  '-',
  fajr,
  '06:30',
  '12:00',
  '15:00',
  '18:00',
  '19:00',
  '01-${month.month.toString().padLeft(2, '0')}-${month.year}',
);

Map<String, dynamic> _calendarData() => {
  'code': 200,
  'data': [
    {
      'timings': validPrayerTimesResponse()['data']['timings'],
      'date': {
        'gregorian': {
          'date': '01-10-2026',
          'weekday': {'en': 'Thursday'},
        },
        'hijri': {'date': '20-04-1448'},
      },
    },
  ],
};

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'settings refresh waits for the running request and then loads fresh data',
    () async {
      final gate = RefreshCoordinator();
      final pending = Completer<bool>();
      final initial = gate.run(() => pending.future);
      var calls = 0;
      final reload = gate.runAfterCurrent(() async {
        calls++;
        return true;
      });
      expect(calls, 0);
      pending.complete(false);
      expect(await initial, isFalse);
      expect(await reload, isTrue);
      expect(calls, 1);
    },
  );

  test('concurrent refresh callers share one request', () async {
    final gate = RefreshCoordinator();
    final result = Completer<bool>();
    var calls = 0;
    Future<bool> fetch() {
      calls++;
      return result.future;
    }

    final first = gate.run(fetch);
    expect(identical(first, gate.run(fetch)), isTrue);
    expect(calls, 1);
    expect(gate.canRefreshAutomatically, isFalse);
    result.complete(true);
    expect(await first, isTrue);
    expect(gate.canRefreshAutomatically, isTrue);
  });

  test(
    'failed refresh backs off automatic calls but permits manual retry',
    () async {
      var now = DateTime(2026, 10, 7);
      final gate = RefreshCoordinator(now: () => now);
      var calls = 0;
      Future<bool> fail() async {
        calls++;
        return false;
      }

      await gate.run(fail);
      now = now.add(const Duration(seconds: 59));
      await gate.run(fail, automatic: true);
      expect(calls, 1);
      await gate.run(fail);
      expect(calls, 2);
      now = now.add(const Duration(minutes: 1));
      await gate.run(() async => true, automatic: true);
      expect(gate.canRefreshAutomatically, isTrue);
    },
  );

  test(
    'refresh exception releases ownership and allows explicit recovery',
    () async {
      final gate = RefreshCoordinator();
      await expectLater(
        gate.run(() async => throw StateError('offline')),
        throwsStateError,
      );
      expect(gate.canRefreshAutomatically, isFalse);
      expect(await gate.run(() async => true), isTrue);
    },
  );

  test(
    'background setup shares requests, retries failures, and runs once after success',
    () async {
      var attempts = 0;
      final pending = Completer<void>();
      final setup = BackgroundSetup(() async {
        attempts++;
        if (attempts == 1) throw StateError('plugin unavailable');
        await pending.future;
      });
      await setup.run();
      expect(setup.failed, isTrue);
      final retry = setup.run();
      expect(identical(retry, setup.run()), isTrue);
      expect(setup.running, isTrue);
      pending.complete();
      await retry;
      await setup.run();
      expect(attempts, 2);
      expect(setup.complete, isTrue);
      expect(setup.failed, isFalse);
      setup.dispose();
    },
  );

  test(
    'cache-only reads use valid data without making network requests',
    () async {
      const location = {
        'latitude': 51.5074,
        'longitude': -0.1278,
        'type': 'coordinates',
      };
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 503);
      });
      expect(
        (await api.getDataFromDay(
          0,
          location,
          client: client,
          cacheOnly: true,
        ))['error'],
        'cache_missing',
      );
      final path = (await helper.constructAPIParameters(
        '',
        helper.dateFormatter(DateTime.now()),
        location,
        Future.value(prefs),
      ))!;
      await prefs.setString(
        helper.prayerTimesCacheKey(path),
        jsonEncode(validPrayerTimesResponse()),
      );
      final cached = await api.getDataFromDay(
        0,
        location,
        client: client,
        cacheOnly: true,
      );
      expect(cached['error'], isEmpty);
      expect(cached['jsonData']['data']['timings']['Fajr'], '05:00');
      expect(calls, 0);
    },
  );

  test('Hadith trims and encodes queries and skips whitespace', () async {
    var calls = 0;
    late Uri uri;
    final client = MockClient((request) async {
      calls++;
      uri = request.url;
      return http.Response('{"results":[]}', 200);
    });
    expect(await getSimilarHadith('   ', client: client), isEmpty);
    expect(calls, 0);
    expect(
      await getSimilarHadith('  دعاء & mercy? # +  ', client: client),
      isEmpty,
    );
    expect(uri.queryParameters['searchQuery'], 'دعاء & mercy? # +');
    expect(calls, 1);
  });

  test(
    'Hadith distinguishes service, malformed, and connection failures from zero matches',
    () async {
      for (final response in [
        http.Response('', 503),
        http.Response('bad json', 200),
        http.Response('{}', 200),
        http.Response('{"results":[{}]}', 200),
      ]) {
        await expectLater(
          getSimilarHadith('query', client: MockClient((_) async => response)),
          throwsA(isA<HadithSearchException>()),
        );
      }
      await expectLater(
        getSimilarHadith(
          'query',
          client: MockClient(
            (_) async => throw const SocketException('offline'),
          ),
        ),
        throwsA(isA<HadithSearchException>()),
      );
    },
  );

  test('Hadith slow requests have a bounded timeout', () async {
    final pending = Completer<http.Response>();
    await expectLater(
      getSimilarHadith(
        'query',
        client: MockClient((_) => pending.future),
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<HadithSearchException>()),
    );
    pending.complete(http.Response('{"results":[]}', 200));
  });

  testWidgets('Hadith cancel and blank search make no requests', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      HadithCustomSearchClass(
        search: (_) async {
          calls++;
          return [];
        },
      ),
    );
    await tester.tap(find.text(_label('Cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text(_label('Search')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(LoadingIndicator), findsNothing);
  });

  testWidgets('Hadith failure ends loading and retry can show zero matches', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      HadithCustomSearchClass(
        search: (_) async {
          if (++calls == 1) throw const HadithSearchException();
          return [];
        },
      ),
    );
    await tester.enterText(find.byType(TextField), 'mercy');
    await tester.tap(find.text(_label('Search')));
    await tester.pumpAndSettle();
    expect(find.text(_label('Hadith_Search_Error')), findsOneWidget);
    expect(find.byType(LoadingIndicator), findsNothing);
    await tester.tap(find.text(_label('Reload')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text(_label('Custom_Search_Empty_Page_Text')), findsOneWidget);
    expect(find.text(_label('Hadith_Search_Error')), findsNothing);
  });

  test('calendar validates response shape, times, and Gregorian dates', () {
    expect(
      parseCalendarResponse(jsonEncode(_calendarData())).single.fajr,
      '05:00',
    );
    for (final invalid in [
      null,
      {},
      {'code': 200, 'data': []},
      {
        'code': 200,
        'data': [{}],
      },
    ]) {
      expect(
        () => parseCalendarResponse(jsonEncode(invalid)),
        throwsFormatException,
      );
    }
    final time = _calendarData();
    time['data'][0]['timings']['Fajr'] = '99:00';
    expect(
      () => parseCalendarResponse(jsonEncode(time)),
      throwsFormatException,
    );
    final date = _calendarData();
    date['data'][0]['date']['gregorian']['date'] = '31-02-2026';
    expect(
      () => parseCalendarResponse(jsonEncode(date)),
      throwsFormatException,
    );
  });

  testWidgets(
    'calendar newest request wins when months complete out of order',
    (tester) async {
      final requests = <Completer<List<DetailedDates>>>[];
      final months = <DateTime>[];
      await _pump(
        tester,
        MonthsPageClass(
          loadMonth: (month) {
            months.add(month);
            final pending = Completer<List<DetailedDates>>();
            requests.add(pending);
            return pending.future;
          },
        ),
      );
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      expect(requests, hasLength(2));
      requests[1].complete([_day(months[1], '05:22')]);
      await tester.pumpAndSettle();
      requests[0].complete([_day(months[0], '04:11')]);
      await tester.pumpAndSettle();
      expect(find.text('05:22'), findsOneWidget);
      expect(find.text('04:11'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar failed month retains prior data and allows recovery', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      MonthsPageClass(
        loadMonth: (month) async {
          calls++;
          if (calls == 2) throw const SocketException('offline');
          return [_day(month, calls == 1 ? '05:22' : '06:33')];
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_forward_ios));
    await tester.pumpAndSettle();
    expect(find.text('05:22'), findsOneWidget);
    expect(
      find.textContaining("Couldn't load the selected month"),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text(_label('Reload')));
    await tester.pumpAndSettle();
    expect(find.text('06:33'), findsOneWidget);
    expect(
      find.textContaining("Couldn't load the selected month"),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar ignores completion after leaving the page', (
    tester,
  ) async {
    final pending = Completer<List<DetailedDates>>();
    await _pump(tester, MonthsPageClass(loadMonth: (_) => pending.future));
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete([_day(DateTime(2026, 10), '05:22')]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Qiblah unsupported devices show explanation without endless loading',
    (tester) async {
      await _pump(tester, QiblahClass(sensorSupport: () async => false));
      await tester.pumpAndSettle();
      expect(find.text(_label('Qiblah_Unsupported')), findsOneWidget);
      expect(find.byType(LoadingIndicator), findsNothing);
    },
  );

  testWidgets('Qiblah null sensor response offers retry', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      QiblahClass(sensorSupport: () async => ++calls == 1 ? null : false),
    );
    await tester.pumpAndSettle();
    expect(find.text(_label('Qiblah_Sensor_Error')), findsOneWidget);
    await tester.tap(find.text(_label('Reload')));
    await tester.pumpAndSettle();
    expect(find.text(_label('Qiblah_Unsupported')), findsOneWidget);
  });

  for (final status in [
    const LocationStatus(false, LocationPermission.denied),
    const LocationStatus(true, LocationPermission.deniedForever),
  ]) {
    testWidgets(
      'Qiblah ${status.status}, services ${status.enabled} has settings action',
      (tester) async {
        await _pump(
          tester,
          Scaffold(body: QiblahCompass(checkLocation: () async => status)),
        );
        await tester.pumpAndSettle();
        expect(find.text(_label('Qiblah_Open_Settings')), findsOneWidget);
        expect(find.byType(LoadingIndicator), findsNothing);
      },
    );
  }

  testWidgets('Qiblah location failures offer retry', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      Scaffold(
        body: QiblahCompass(
          checkLocation: () async {
            if (++calls == 1) throw StateError('plugin failed');
            return const LocationStatus(false, LocationPermission.denied);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_label('Qiblah_Location_Error')), findsOneWidget);
    expect(find.text(_label('Reload')), findsOneWidget);
    await tester.tap(find.text(_label('Reload')));
    await tester.pumpAndSettle();
    expect(find.text(_label('Qiblah_Open_Settings')), findsOneWidget);
    expect(find.text(_label('Qiblah_Location_Error')), findsNothing);
  });

  testWidgets('Qiblah sensor check timeout ends loading', (tester) async {
    final pending = Completer<bool?>();
    await _pump(tester, QiblahClass(sensorSupport: () => pending.future));
    expect(find.byType(LoadingIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text(_label('Qiblah_Sensor_Error')), findsOneWidget);
    expect(find.byType(LoadingIndicator), findsNothing);
    pending.complete(false);
  });

  testWidgets('Qiblah silent direction stream times out and can reconnect', (
    tester,
  ) async {
    final controller = StreamController<QiblahDirection>();
    var connections = 0;
    await _pump(
      tester,
      Scaffold(
        body: QiblahCompassWidget(
          directions: () {
            connections++;
            return connections == 1
                ? controller.stream
                : const Stream<QiblahDirection>.empty();
          },
        ),
      ),
    );
    expect(find.byType(LoadingIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text(_label('Qiblah_Sensor_Error')), findsOneWidget);
    await tester.tap(find.text(_label('Reload')));
    await tester.pumpAndSettle();
    expect(connections, 2);
    expect(find.byType(LoadingIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(controller.close());
  });

  testWidgets('leaving Qiblah during permission request is safe', (
    tester,
  ) async {
    final pending = Completer<LocationPermission>();
    await _pump(
      tester,
      Scaffold(
        body: QiblahCompass(
          checkLocation: () async =>
              const LocationStatus(true, LocationPermission.denied),
          requestPermissions: () => pending.future,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(LocationPermission.denied);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final failed in [false, true]) {
    testWidgets(
      'Qiblah ${failed ? 'error' : 'closed'} direction stream is recoverable',
      (tester) async {
        await _pump(
          tester,
          Scaffold(
            body: QiblahCompassWidget(
              directions: () => failed
                  ? Stream<QiblahDirection>.error(
                      StateError('sensor unavailable'),
                    )
                  : const Stream<QiblahDirection>.empty(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(_label('Qiblah_Sensor_Error')), findsOneWidget);
        expect(find.byType(LoadingIndicator), findsNothing);
      },
    );
  }
}
