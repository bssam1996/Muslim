import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim/UI/month/months_page.dart';
import 'package:muslim/UI/mosque/nearest_mosque_page.dart';
import 'package:muslim/UI/prayer_notifications/prayer_notifications.dart';
import 'package:muslim/UI/radio/radio_page.dart';
import 'package:muslim/UI/radio/radio_stations_data.dart';
import 'package:muslim/UI/settings/settings.dart';
import 'package:muslim/home_page.dart';
import 'package:muslim/shared/app_navigation.dart';
import 'package:muslim/shared/prayer_date_header.dart';
import 'package:muslim/shared/prayer_time_row.dart';
import 'package:muslim/shared/prayer_countdown.dart';
import 'package:muslim/utils/api_utils.dart' as api;
import 'package:muslim/utils/helper.dart' as helper;
import 'package:muslim/shared/constants.dart' as constants;
import 'package:muslim/utils/mosque_utils.dart';
import 'package:muslim/utils/mosque_search_cache.dart';
import 'package:muslim/utils/prayer_alarm_scheduler.dart';
import 'package:muslim/utils/prayer_notification_status.dart';
import 'package:muslim/utils/prayer_schedule.dart';
import 'package:muslim/utils/radio_playback.dart';
import 'package:muslim/utils/serial_task_queue.dart';
import 'package:muslim/utils/snapshot_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_times_cache_test.dart' show validPrayerTimesResponse;
import 'support/daily_use_test_host.dart';

class _Audio implements RadioAudioBackend {
  final events = StreamController<PlayerState>.broadcast(sync: true);
  Completer<void>? preparation;
  bool pauseFails = false;
  int stops = 0;
  int disposals = 0;
  @override
  Stream<PlayerState> get states => events.stream;
  @override
  Future<void> play(String url) async {
    await preparation?.future;
  }

  @override
  Future<void> pause() async {
    if (pauseFails) throw StateError('Audio interruption');
    events.add(PlayerState.paused);
  }

  @override
  Future<void> resume() async {
    events.add(PlayerState.playing);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

const _location = MosqueSearchLocation(
  latitude: 51.5,
  longitude: -.1,
  fromFallback: false,
);
const _mosque = MosquePlace(
  id: 'one',
  name: 'Example Mosque',
  latitude: 51.51,
  longitude: -.11,
  distanceMeters: 350,
  address: 'Example Road',
);
const _result = MosqueSearchResult(mosques: [_mosque], radiusMeters: 3000);

String _calendarBody(DateTime month) => jsonEncode({
  'code': 200,
  'data': [
    for (
      var day = 1;
      day <= DateTime(month.year, month.month + 1, 0).day;
      day++
    )
      {
        'date': {
          'gregorian': {
            'date': helper.dateFormatter(
              DateTime(month.year, month.month, day),
            ),
            'weekday': {'en': 'Thursday'},
          },
          'hijri': {'date': '01-04-1448'},
        },
        'timings': {
          'Fajr': '05:00',
          'Sunrise': '06:30',
          'Dhuhr': '12:15',
          'Asr': '15:30',
          'Maghrib': '18:00',
          'Isha': '19:30',
        },
      },
  ],
});

Future<void> _seedHome() async {
  final prefs = await SharedPreferences.getInstance();
  final location =
      jsonDecode(prefs.getString('location')!) as Map<String, dynamic>;
  for (var offset = 0; offset < 7; offset++) {
    final date = prayerDate(DateTime.now(), offset);
    final response = validPrayerTimesResponse();
    response['data']['date']['gregorian'] = {
      'date': helper.dateFormatter(date),
    };
    final path = (await helper.constructAPIParameters(
      '',
      helper.dateFormatter(date),
      location,
      Future.value(prefs),
    ))!;
    await prefs.setString(
      helper.prayerTimesCacheKey(path),
      jsonEncode(response),
    );
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectMonthlyTable(WidgetTester tester, int columns) {
  final grid = find.byType(SfDataGrid);
  expect(grid, findsOneWidget);
  expect(tester.widget<SfDataGrid>(grid).columns, hasLength(columns));
  for (final name in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
    final header = find.text('Months_Column_$name'.tr()).first;
    final bounds = tester.getRect(header);
    final table = tester.getRect(grid);
    expect(bounds.left, greaterThanOrEqualTo(table.left));
    expect(bounds.right, lessThanOrEqualTo(table.right));
  }
  for (final element
      in find
          .descendant(of: grid, matching: find.byType(Scrollable))
          .evaluate()) {
    final scroll = tester.state<ScrollableState>(find.byWidget(element.widget));
    if (scroll.widget.axisDirection == AxisDirection.left ||
        scroll.widget.axisDirection == AxisDirection.right) {
      expect(scroll.position.maxScrollExtent, lessThanOrEqualTo(.5));
    }
  }
  expect(find.byKey(const ValueKey('calendar_day_selector')), findsNothing);
}

void main() {
  initializeDailyUseTests();

  test(
    'serialized writes retain user order and recover after a failed write',
    () async {
      final queue = SerialTaskQueue();
      final gate = Completer<void>();
      final events = <int>[];
      final first = queue.run(() async {
        await gate.future;
        events.add(1);
      });
      final failed = queue.run<void>(() async {
        events.add(2);
        throw StateError('Storage failed');
      });
      final failureCheck = expectLater(failed, throwsStateError);
      final last = queue.run(() async {
        events.add(3);
      });
      expect(events, isEmpty);
      gate.complete();
      await first;
      await failureCheck;
      await last;
      expect(events, [1, 2, 3]);
    },
  );

  test(
    'snapshot caches bound retention and separate calculation identities',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final cache = SnapshotCache(prefs, 'calendar-cache-v1/', limit: 2);
      await cache.write(
        'London/default/October',
        'one',
        now: DateTime(2026, 10, 1),
      );
      await cache.write(
        'London/other/October',
        'two',
        now: DateTime(2026, 10, 2),
      );
      expect(cache.read('London/default/October')?.payload, 'one');
      expect(cache.read('London/other/October')?.payload, 'two');
      await cache.write(
        'Cairo/default/October',
        'three',
        now: DateTime(2026, 10, 3),
      );
      expect(cache.read('London/default/October'), isNull);
      expect(cache.latest()?.payload, 'three');
      await prefs.setString('calendar-cache-v1/broken', '{}');
      expect(cache.read('broken'), isNull);
      expect(cache.latest()?.payload, 'three');
      expect(prefs.getString('location'), isNotNull);
    },
  );

  test(
    'prayer cache clearing includes months and preserves mosque results and preferences',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await SnapshotCache(
        prefs,
        'calendar-cache-v1/',
      ).write('month', 'calendar');
      await SnapshotCache(
        prefs,
        'mosque-search-cache-v1/',
      ).write('place', 'mosques');
      await prefs.setInt(constants.prayerTunePreferenceKey('Fajr'), 4);
      expect(await api.clearPrayerTimesCache(Future.value(prefs)), 1);
      expect(SnapshotCache(prefs, 'calendar-cache-v1/').read('month'), isNull);
      expect(
        SnapshotCache(prefs, 'mosque-search-cache-v1/').read('place')?.payload,
        'mosques',
      );
      expect(prefs.getInt(constants.prayerTunePreferenceKey('Fajr')), 4);
    },
  );

  test('only complete requested calendar months enter the cache', () {
    final month = DateTime(2026, 10);
    final days = parseCalendarResponse(_calendarBody(month));
    validateCalendarMonth(days, month);
    expect(
      () => validateCalendarMonth(days.take(30).toList(), month),
      throwsFormatException,
    );
    expect(
      () => validateCalendarMonth(days, DateTime(2026, 11)),
      throwsFormatException,
    );
    expect(
      () => validateCalendarMonth([...days.take(30), days.first], month),
      throwsFormatException,
    );
  });

  test(
    'explicit refresh preserves valid daily cache when the network fails',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final date = prayerDate(DateTime.now());
      final location =
          jsonDecode(prefs.getString('location')!) as Map<String, dynamic>;
      final path = (await helper.constructAPIParameters(
        '',
        helper.dateFormatter(date),
        location,
        Future.value(prefs),
      ))!;
      final key = helper.prayerTimesCacheKey(path);
      final response = validPrayerTimesResponse();
      await prefs.setString(key, jsonEncode(response));
      var requests = 0;
      final failed = await api.getDataFromDay(
        0,
        location,
        preferences: Future.value(prefs),
        forceRefresh: true,
        client: MockClient((_) async {
          requests++;
          return http.Response('', 503);
        }),
      );
      expect(failed['error'], isNotEmpty);
      expect(requests, 1);
      expect(jsonDecode(prefs.getString(key)!), response);
      final restored = await api.getDataFromDay(
        0,
        location,
        preferences: Future.value(prefs),
        cacheOnly: true,
      );
      expect(restored['fromCache'], isTrue);
      expect(restored['error'], isEmpty);
    },
  );

  test(
    'mosque snapshot roundtrip keeps centre, radius, distances and rejects invalid coordinates',
    () {
      final (location, result) = decodeMosqueSearch(
        encodeMosqueSearch(_location, _result),
      );
      expect(location.latitude, _location.latitude);
      expect(result.radiusMeters, 3000);
      expect(result.mosques.single.distanceMeters, 350);
      final bad = jsonDecode(encodeMosqueSearch(_location, _result)) as Map;
      bad['latitude'] = 200;
      expect(() => decodeMosqueSearch(jsonEncode(bad)), throwsFormatException);
    },
  );

  test(
    'notification status excludes absent, expired, disabled and old-configuration alarms',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prayerNotification', true);
      final now = DateTime(2026, 10, 8, 12);
      PrayerAlarm alarm(
        int id,
        String name,
        int minutes, {
        String configuration = 'current',
      }) => PrayerAlarm(
        id: id,
        name: name,
        time: now.add(Duration(minutes: minutes)),
        configuration: configuration,
        channelId: constants.prayerNotificationAndroidChannelId(
          name,
          constants.prayerNotificationModeVibrationOnly,
          null,
        ),
      );
      final alarms = [
        alarm(1000000, 'Fajr', -5),
        alarm(1000001, 'Dhuhr', 10),
        alarm(1000002, 'Asr', 20),
        alarm(1000003, 'Maghrib', 30, configuration: 'old'),
        alarm(1000004, 'Isha', 40),
      ];
      await prefs.setString(
        prayerAlarmManifestKey,
        jsonEncode({'alarms': alarms.map((a) => a.toJson()).toList()}),
      );
      await prefs.setBool(
        constants.prayerNotificationPreferenceKey('Asr'),
        false,
      );
      final pending = {1000000, 1000001, 1000002, 1000003};
      expect(
        confirmedPrayerAlarms(
          prefs,
          pending,
          configuration: 'current',
          now: now,
        ).map((a) => a.name),
        ['Dhuhr'],
      );
      await prefs.setBool('prayerNotification', false);
      expect(
        confirmedPrayerAlarms(
          prefs,
          pending,
          configuration: 'current',
          now: now,
        ),
        isEmpty,
      );
    },
  );

  test(
    'notification status does not announce an alarm with an old sound channel',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prayerNotification', true);
      final now = DateTime(2026, 10, 8, 12);
      final alarm = PrayerAlarm(
        id: 1000000,
        name: 'Fajr',
        time: now.add(const Duration(hours: 1)),
        configuration: 'current',
        channelId: constants.prayerNotificationAndroidChannelId(
          'Fajr',
          constants.prayerNotificationModeVibrationOnly,
          null,
        ),
      );
      await prefs.setString(
        prayerAlarmManifestKey,
        jsonEncode({
          'alarms': [alarm.toJson()],
        }),
      );
      await prefs.setString(
        constants.prayerNotificationModePreferenceKey('Fajr'),
        constants.prayerNotificationModeCustomSound,
      );
      await prefs.setString(
        constants.prayerNotificationSoundPreferenceKey('Fajr'),
        'adhan',
      );
      expect(
        confirmedPrayerAlarms(
          prefs,
          {alarm.id},
          configuration: 'current',
          now: now,
        ),
        isEmpty,
      );
    },
  );

  test('radio connects, pauses, resumes and stops when disposed', () async {
    final audio = _Audio();
    final playback = RadioPlayback(createPlayer: () => audio);
    await playback.connect('https://example.test/radio');
    expect(playback.state, RadioPlaybackState.playing);
    await playback.toggle();
    expect(playback.state, RadioPlaybackState.paused);
    await playback.toggle();
    expect(playback.state, RadioPlaybackState.playing);
    playback.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(audio.stops, greaterThan(0));
    expect(audio.disposals, 1);
    await audio.events.close();
  });

  test(
    'timed-out radio uses a new player and late preparation cannot take over retry',
    () async {
      final old = _Audio()..preparation = Completer<void>();
      final next = _Audio();
      var count = 0;
      final playback = RadioPlayback(
        createPlayer: () => count++ == 0 ? old : next,
        connectionTimeout: const Duration(milliseconds: 10),
      );
      await playback.connect('https://example.test/slow');
      expect(playback.state, RadioPlaybackState.error);
      await playback.connect('https://example.test/retry');
      expect(playback.state, RadioPlaybackState.playing);
      old.preparation!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(playback.state, RadioPlaybackState.playing);
      expect(next.stops, 0);
      expect(old.disposals, 1);
      playback.dispose();
      await old.events.close();
      await next.events.close();
    },
  );

  test(
    'radio failures stop audio and expose retry instead of leaving a false playing state',
    () async {
      final audio = _Audio()..pauseFails = true;
      final playback = RadioPlayback(createPlayer: () => audio);
      await playback.connect('https://example.test/radio');
      await playback.toggle();
      expect(playback.state, RadioPlaybackState.error);
      await Future<void>.delayed(Duration.zero);
      expect(audio.disposals, 1);
      playback.dispose();
      await audio.events.close();
    },
  );

  test('closing a buffering radio ignores late completion', () async {
    final audio = _Audio()..preparation = Completer<void>();
    final playback = RadioPlayback(createPlayer: () => audio);
    final pending = playback.connect('https://example.test/slow');
    await Future<void>.delayed(Duration.zero);
    playback.dispose();
    audio.preparation!.complete();
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(audio.disposals, 1);
    expect(audio.stops, greaterThan(0));
    await audio.events.close();
  });

  testWidgets(
    'Home countdown ticks without rebuilding prayer cards and Sunrise is an event',
    (tester) async {
      await _seedHome();
      await pumpDailyPage(
        tester,
        MyHomePage(title: 'App_Title', loadHadith: () async => null),
        width: 393,
        scale: 1,
      );
      expect(find.text('Home_Cached_Timings'.tr()), findsNothing);
      expect(find.byKey(const ValueKey('home_change_location')), findsNothing);
      final before = tester.widget<PrayerDateHeader>(
        find.byType(PrayerDateHeader).first,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        identical(
          before,
          tester.widget<PrayerDateHeader>(find.byType(PrayerDateHeader).first),
        ),
        isTrue,
      );
      final clock = ValueNotifier(DateTime(2026, 10, 8, 6));
      addTearDown(clock.dispose);
      await pumpDailyPage(
        tester,
        Scaffold(
          body: PrayerCountdown(
            name: 'Sunrise',
            time: DateTime(2026, 10, 8, 6, 30),
            displayTime: '06:30',
            clock: clock,
          ),
        ),
        scale: 1,
      );
      expect(find.textContaining('Home_Next_Event'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    testWidgets(
      'calendar table swipes change months without intercepting vertical scrolling in $locale',
      (tester) async {
        final initial = DateTime(DateTime.now().year, DateTime.now().month);
        final requested = <DateTime>[];
        await pumpDailyPage(
          tester,
          MonthsPageClass(
            loadMonth: (month) async {
              requested.add(month);
              return parseCalendarResponse(_calendarBody(month));
            },
          ),
          locale: locale,
          width: 390,
          height: 850,
          scale: 1,
        );
        Future<void> swipe(Offset movement) async {
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(SfDataGrid)),
          );
          for (var step = 0; step < 6; step++) {
            await gesture.moveBy(movement / 6);
            await tester.pump(const Duration(milliseconds: 60));
          }
          await tester.pump(const Duration(milliseconds: 200));
          await gesture.up();
          await tester.pumpAndSettle();
        }

        final forward = locale.languageCode == 'ar' ? 180.0 : -180.0;
        await swipe(Offset(forward, 0));
        expect(requested.last, DateTime(initial.year, initial.month + 1));
        await swipe(Offset(-forward, 0));
        expect(requested.last, initial);
        double verticalOffset() => find
            .descendant(
              of: find.byType(SfDataGrid),
              matching: find.byType(Scrollable),
            )
            .evaluate()
            .map(
              (element) =>
                  tester.state<ScrollableState>(find.byWidget(element.widget)),
            )
            .where((state) => state.position.axis == Axis.vertical)
            .fold<double>(0, (total, state) => total + state.position.pixels);
        final beforeScroll = verticalOffset();
        await swipe(const Offset(0, -140));
        expect(verticalOffset(), greaterThan(beforeScroll));
        expect(requested, [
          initial,
          DateTime(initial.year, initial.month + 1),
          initial,
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('prayer names and clocks form a centered pair in $locale', (
      tester,
    ) async {
      await pumpDailyPage(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (context) => PrayerTimeRow(
                key: const ValueKey('aligned_prayer'),
                label: 'Fajr'.tr(context: context),
                time: '05:00',
                dense: true,
              ),
            ),
          ),
        ),
        locale: locale,
        width: 390,
        scale: 1,
      );
      final tile = tester.getRect(find.byKey(const ValueKey('aligned_prayer')));
      final clock = tester.getRect(find.text('05:00'));
      final label = tester.getRect(find.text('Fajr'.tr()));
      if (locale.languageCode == 'ar') {
        expect(label.left - clock.right, closeTo(64, 1));
        expect((label.left + clock.right) / 2, closeTo(tile.center.dx, 1));
      } else {
        expect(clock.left - label.right, closeTo(64, 1));
        expect((clock.left + label.right) / 2, closeTo(tile.center.dx, 1));
      }
    });

    testWidgets(
      'monthly table keeps all timings visible when resized in $locale',
      (tester) async {
        final month = DateTime(DateTime.now().year, DateTime.now().month);
        await pumpDailyPage(
          tester,
          MonthsPageClass(
            loadMonth: (_) async => parseCalendarResponse(_calendarBody(month)),
          ),
          locale: locale,
          width: 390,
          height: 850,
          scale: 1,
        );
        _expectMonthlyTable(tester, 7);
        tester.view.physicalSize = const Size(1100, 850);
        await tester.pumpAndSettle();
        _expectMonthlyTable(tester, 9);
        tester.view.physicalSize = const Size(320, 850);
        await tester.pumpAndSettle();
        _expectMonthlyTable(tester, 7);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'notification master preserves selections and test action is separate from preview in $locale',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('prayerNotification', true);
        await prefs.setBool(
          constants.prayerNotificationPreferenceKey('Fajr'),
          true,
        );
        await prefs.setBool(
          constants.prayerNotificationPreferenceKey('Isha'),
          false,
        );
        var reconciles = 0;
        var tests = 0;
        await pumpDailyPage(
          tester,
          PrayerNotificationsPageClass(
            prefs: Future.value(prefs),
            loadStatus: () async => const PrayerNotificationStatus(
              notifications: true,
              exactAlarms: true,
            ),
            requestPermissions: () async => true,
            reconcile: () async {
              reconciles++;
              return true;
            },
            testNotification: () async {
              tests++;
            },
          ),
          locale: locale,
          scale: 1,
        );
        await _tapVisible(tester, find.byType(Switch).first);
        expect(prefs.getBool('prayerNotification'), isFalse);
        expect(
          prefs.getBool(constants.prayerNotificationPreferenceKey('Fajr')),
          isTrue,
        );
        expect(
          prefs.getBool(constants.prayerNotificationPreferenceKey('Isha')),
          isFalse,
        );
        await _tapVisible(tester, find.byType(Switch).first);
        expect(prefs.getBool('prayerNotification'), isTrue);
        expect(
          prefs.getBool(constants.prayerNotificationPreferenceKey('Isha')),
          isFalse,
        );
        expect(reconciles, 2);
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_notification')),
        );
        expect(tests, 1);
        expect(reconciles, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'turning off the last prayer keeps the master switch independent in $locale',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('prayerNotification', true);
        for (final name in constants.PRAYER_NOTIFICATION_NAMES) {
          await prefs.setBool(
            constants.prayerNotificationPreferenceKey(name),
            name == 'Fajr',
          );
        }
        await pumpDailyPage(
          tester,
          PrayerNotificationsPageClass(
            prefs: Future.value(prefs),
            loadStatus: () async => const PrayerNotificationStatus(
              notifications: true,
              exactAlarms: false,
            ),
            reconcile: () async => true,
          ),
          locale: locale,
          scale: 1,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('prayer_switch_Fajr')),
        );
        expect(prefs.getBool('prayerNotification'), isTrue);
        expect(
          prefs.getBool(constants.prayerNotificationPreferenceKey('Fajr')),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reset adjustments requires confirmation and preserves other settings in $locale',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(constants.prayerTunePreferenceKey('Fajr'), 6);
        await prefs.setInt(constants.prayerTunePreferenceKey('Isha'), -3);
        await prefs.setInt('adjustment', 2);
        final location = prefs.getString('location');
        await pumpDailyPage(
          tester,
          SettingsPageClass(prefs: Future.value(prefs)),
          locale: locale,
          scale: 1,
        );
        await _tapVisible(tester, find.text('Settings_Advanced'.tr()));
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('reset_prayer_adjustments')),
        );
        await _tapVisible(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Cancel'.tr()),
          ),
        );
        expect(prefs.getInt(constants.prayerTunePreferenceKey('Fajr')), 6);
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('reset_prayer_adjustments')),
        );
        await _tapVisible(
          tester,
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextButton),
              )
              .last,
        );
        for (final name in constants.PRAYER_NAMES) {
          expect(prefs.getInt(constants.prayerTunePreferenceKey(name)), 0);
        }
        expect(prefs.getInt('adjustment'), 2);
        expect(prefs.getString('location'), location);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'calendar reopens a validated saved month offline with full monthly table in $locale',
      (tester) async {
        final month = DateTime(DateTime.now().year, DateTime.now().month);
        await pumpDailyPage(
          tester,
          MonthsPageClass(fetchMonth: (_) async => _calendarBody(month)),
          locale: locale,
          scale: 1,
        );
        expect(
          tester.widget<SfDataGrid>(find.byType(SfDataGrid)).source.rows,
          hasLength(DateTime(month.year, month.month + 1, 0).day),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpDailyPage(
          tester,
          MonthsPageClass(fetchMonth: (_) async => throw StateError('Offline')),
          locale: locale,
          scale: 1,
        );
        expect(find.text('Calendar_Cached_Offline'.tr()), findsOneWidget);
        expect(
          tester.widget<SfDataGrid>(find.byType(SfDataGrid)).source.rows,
          hasLength(DateTime(month.year, month.month + 1, 0).day),
        );
        _expectMonthlyTable(tester, 7);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('cached calendar stays usable in short landscape in $locale', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final month = DateTime(DateTime.now().year, DateTime.now().month);
      final location = await api.getSavedLocation();
      final path = (await helper.constructAPIParameters(
        'calendar',
        '${month.year}/${month.month}',
        location,
        Future.value(prefs),
      ))!;
      await SnapshotCache(
        prefs,
        'calendar-cache-v1/',
      ).write(path, _calendarBody(month));
      await pumpDailyPage(
        tester,
        MonthsPageClass(fetchMonth: (_) async => throw StateError('Offline')),
        locale: locale,
        width: 700,
        height: 380,
        scale: 1.5,
      );
      expect(find.text('Calendar_Cached_Offline'.tr()), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(SfDataGrid),
        120,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      _expectMonthlyTable(tester, 9);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'mosque refresh failure and reopening retain results with list/map selection in $locale',
      (tester) async {
        var fail = false;
        await pumpDailyPage(
          tester,
          NearestMosquePageClass(
            loadSearch: (_) async {
              if (fail) throw StateError('Offline');
              return (_location, _result);
            },
            mapBuilder: (_, __) => const ColoredBox(color: Colors.blue),
          ),
          locale: locale,
          scale: 1,
        );
        await _tapVisible(tester, find.byKey(const ValueKey('mosque_one')));
        expect(
          tester
              .widget<ListTile>(find.byKey(const ValueKey('mosque_one')))
              .selected,
          isTrue,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('mosque_map_toggle'), skipOffstage: false),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('mosque_map_panel'), skipOffstage: false),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('mosque_map_panel')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Example Mosque'),
          180,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Example Mosque'), findsOneWidget);
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('mosque_list_toggle'), skipOffstage: false),
        );
        fail = true;
        await _tapVisible(
          tester,
          find.widgetWithText(ElevatedButton, 'Search'.tr()),
        );
        await tester.scrollUntilVisible(
          find.text('Example Mosque'),
          180,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Example Mosque'), findsOneWidget);
        expect(
          find.textContaining(
            'Mosque_Previous_Results'.tr(),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpDailyPage(
          tester,
          NearestMosquePageClass(
            loadSearch: (_) async => throw StateError('Offline'),
          ),
          locale: locale,
          scale: 1,
        );
        await tester.scrollUntilVisible(
          find.text('Example Mosque'),
          180,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Example Mosque'), findsOneWidget);
        expect(
          find.textContaining(
            'Mosque_Saved_Search'
                .tr(namedArgs: {'date': ''})
                .split('·')
                .first
                .trim(),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'empty mosque results offer a larger captured search radius in $locale',
      (tester) async {
        final radii = <int>[];
        await pumpDailyPage(
          tester,
          NearestMosquePageClass(
            loadSearch: (radius) async {
              radii.add(radius);
              return (
                _location,
                MosqueSearchResult(mosques: [], radiusMeters: radius),
              );
            },
          ),
          locale: locale,
          scale: 1,
        );
        await _tapVisible(tester, find.text('Mosque_Expand_Radius'.tr()));
        expect(radii, [3000, 5000]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'radio favorites and compact mode persist through reopening in $locale',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('favorite_radio_station_ids', ['1']);
        await prefs.setBool('radio_list_mode', true);
        await pumpDailyPage(
          tester,
          const RadioPageClass(),
          locale: locale,
          scale: 1,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('radio_favorites_filter')),
        );
        final station = find.byKey(const ValueKey('radio_station_1'));
        expect(station, findsOneWidget);
        final favorite = find.descendant(
          of: station,
          matching: find.byType(IconButton),
        );
        await _tapVisible(tester, favorite);
        expect(prefs.getStringList('favorite_radio_station_ids'), isEmpty);
        expect(find.text('Radio_No_Favorites'.tr()), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpDailyPage(
          tester,
          const RadioPageClass(),
          locale: locale,
          scale: 1,
        );
        expect(
          tester
              .widget<FilterChip>(find.byKey(const ValueKey('radio_list_mode')))
              .selected,
          isTrue,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('radio_favorites_filter')),
        );
        expect(find.text('Radio_No_Favorites'.tr()), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'radio player has explicit play/pause and stops on close in $locale',
      (tester) async {
        final audio = _Audio();
        await pumpDailyPage(
          tester,
          RadioPageClass(createPlayer: () => audio),
          locale: locale,
          scale: 1,
        );
        final name = radioStations.first.nameForLocale(
          tester.element(find.byType(RadioPageClass)),
        );
        await _tapVisible(tester, find.text(name).first);
        expect(find.text('Radio_Playing'.tr()), findsOneWidget);
        await _tapVisible(
          tester,
          find.widgetWithText(TextButton, 'Radio_Pause_Action'.tr()),
        );
        expect(find.text('Radio_Paused'.tr()), findsOneWidget);
        await _tapVisible(
          tester,
          find.widgetWithText(TextButton, 'Close'.tr()),
        );
        expect(audio.disposals, 1);
        await audio.events.close();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    for (final brightness in Brightness.values) {
      for (final (width, height, scale) in [
        (320.0, 1000.0, 3.0),
        (1100.0, 900.0, 1.0),
        (700.0, 380.0, 1.5),
      ]) {
        for (final page in [
          'Home',
          'Settings',
          'Notifications',
          'Calendar',
          'Mosques',
          'Radio',
        ]) {
          testWidgets(
            'daily use $page fits $locale $brightness $width x $height at $scale',
            (tester) async {
              final prefs = await SharedPreferences.getInstance();
              await _seedHome();
              final month = DateTime(DateTime.now().year, DateTime.now().month);
              final widget = switch (page) {
                'Home' => MyHomePage(
                  title: 'App_Title',
                  loadHadith: () async => null,
                ),
                'Settings' => SettingsPageClass(prefs: Future.value(prefs)),
                'Notifications' => PrayerNotificationsPageClass(
                  prefs: Future.value(prefs),
                  loadStatus: () async => const PrayerNotificationStatus(
                    notifications: true,
                    exactAlarms: false,
                  ),
                ),
                'Calendar' => MonthsPageClass(
                  loadMonth: (_) async =>
                      parseCalendarResponse(_calendarBody(month)),
                ),
                'Mosques' => NearestMosquePageClass(
                  loadSearch: (_) async => (_location, _result),
                  mapBuilder: (_, __) => const ColoredBox(color: Colors.blue),
                ),
                _ => const RadioPageClass(),
              };
              await pumpDailyPage(
                tester,
                widget,
                locale: locale,
                brightness: brightness,
                width: width,
                height: height,
                scale: scale,
              );
              if (page == 'Home') {
                final pager = find.byKey(
                  const PageStorageKey('home_prayer_pager'),
                );
                final card = find.byKey(const ValueKey('prayer_timing_page_0'));
                final rows = find.descendant(
                  of: card,
                  matching: find.byType(PrayerTimeRow),
                );
                expect(rows, findsNWidgets(6));
                expect(
                  tester.getRect(rows.last).bottom,
                  lessThanOrEqualTo(tester.getRect(pager).bottom),
                );
                expect(find.byType(AppDrawer), findsNothing);
              }
              if (page == 'Calendar') {
                _expectMonthlyTable(tester, width < 650 ? 7 : 9);
              }
              if (page == 'Mosques' && width < 760) {
                await _tapVisible(
                  tester,
                  find.byKey(
                    const ValueKey('mosque_map_toggle'),
                    skipOffstage: false,
                  ),
                );
                expect(
                  find.byKey(
                    const ValueKey('mosque_map_panel'),
                    skipOffstage: false,
                  ),
                  findsOneWidget,
                );
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
