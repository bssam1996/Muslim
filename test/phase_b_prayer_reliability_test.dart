import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim/utils/api_utils.dart' as api;
import 'package:muslim/utils/helper.dart' as helper;
import 'package:muslim/utils/homewidget_utils.dart';
import 'package:muslim/utils/notification_service.dart';
import 'package:muslim/utils/prayer_alarm_scheduler.dart';
import 'package:muslim/utils/prayer_data_repository.dart';
import 'package:muslim/utils/prayer_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_times_cache_test.dart' show validPrayerTimesResponse;

Map<String, dynamic> _times([String fajr = '05:00']) => {
  'Fajr': fajr,
  'Sunrise': '06:20',
  'Dhuhr': '12:10',
  'Asr': '15:30',
  'Maghrib': '18:00',
  'Isha': '19:20',
};
final _today = DateTime(2026, 10, 7);
final _now = DateTime(2026, 10, 7, 13);
List<PrayerDay> _days() => [
  PrayerDay(_today, _times()),
  PrayerDay(prayerDate(_today, 1), _times('05:12')),
];

class _Backend implements PrayerAlarmBackend {
  final Map<int, PrayerAlarm> alarms = {};
  final Set<int> other = {42};
  final List<String> events = [];
  int schedules = 0;
  int? failAt;
  Completer<void>? blocked;
  @override
  Future<void> schedule(PrayerAlarm alarm) async {
    schedules++;
    events.add('schedule:${alarm.id}');
    if (blocked != null) {
      final wait = blocked!;
      blocked = null;
      await wait.future;
    }
    if (schedules == failAt) throw StateError('OS rejected alarm');
    alarms[alarm.id] = alarm;
  }

  @override
  Future<void> cancel(int id) async {
    events.add('cancel:$id');
    alarms.remove(id);
    other.remove(id);
  }

  @override
  Future<Set<int>> pendingIds() async => {...alarms.keys, ...other};
}

Future<bool> _update(
  _Backend backend,
  SharedPreferences prefs,
  List<PrayerDay> days, {
  Map<String, bool>? enabled,
  Map<String, String>? channels,
  Map<String, String?>? sounds,
  String configuration = 'saved-city-and-method',
}) => PrayerAlarmReconciler(prefs, backend).reconcile(
  days: days,
  configuration: configuration,
  now: _now,
  enabled:
      enabled ?? {for (final name in prayerEvents) name: name != 'Sunrise'},
  channels:
      channels ?? {for (final name in prayerEvents) name: 'channel-$name'},
  sounds: sounds ?? {for (final name in prayerEvents) name: null},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'evening widget previews the actual upcoming day and its Fajr value',
    () {
      final display = widgetPrayerDisplayDay(
        _days(),
        now: DateTime(2026, 10, 7, 22),
      )!;
      expect(display.date, DateTime(2026, 10, 8));
      expect(display.timings['Fajr'], '05:12');
      expect(widgetPrayerDisplayDay(_days(), now: _now)!.date, _today);
      expect(
        widgetPrayerDisplayDay([
          _days().first,
        ], now: DateTime(2026, 10, 7, 22))!.date,
        _today,
      );
    },
  );

  test(
    'notification choice changed during staging cannot be overwritten by old work',
    () async {
      SharedPreferences.setMockInitialValues({'prayerNotification': true});
      final prefs = await SharedPreferences.getInstance();
      final blocked = Completer<void>();
      final backend = _Backend()..blocked = blocked;
      final pending = helper.handleNotifications(
        Future.value(prefs),
        _days(),
        configuration: 'saved-config',
        backend: backend,
        now: _now,
      );
      while (backend.schedules == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await prefs.setBool('prayerNotification', false);
      blocked.complete();
      expect(await pending, isFalse);
      expect(backend.alarms, isEmpty);
      expect(prefs.getBool('prayerNotification'), isFalse);
    },
  );

  for (final stale in [false, true]) {
    test(
      'widget snapshot ${stale ? 'stale' : 'current'} keeps date and language honest',
      () async {
        const widgetChannel = MethodChannel('home_widget');
        final stored = <String, dynamic>{
          'fajr_label': 'الفجر',
          'prayer_unavailable_text': 'مواقيت الصلاة غير متاحة لليوم',
        };
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(widgetChannel, (call) async {
              final args = call.arguments as Map;
              if (call.method == 'saveWidgetData') {
                stored[args['id'] as String] = args['data'];
                return true;
              }
              if (call.method == 'getWidgetData') {
                return stored[args['id']] ?? args['defaultValue'];
              }
              return true;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(widgetChannel, null),
        );
        final date = prayerDate(DateTime.now(), stale ? -1 : 0);
        await updateHomePage(
          [PrayerDay(date, _times())],
          'saved-city-and-method',
          localize: false,
        );
        expect(stored['fajr_label'], 'الفجر');
        expect(stored['fajr_text'], stale ? '-' : '05:00');
        expect(stored['prayer_data_date'], stale ? '' : prayerDateKey(date));
        if (stale) {
          expect(stored['next_prayer_key'], isEmpty);
          expect(
            stored['gregorianDate_text'],
            stored['prayer_unavailable_text'],
          );
        }
        expect(
          jsonDecode(
            stored[widgetPrayerSnapshotKey] as String,
          )['configuration'],
          'saved-city-and-method',
        );
      },
    );
  }

  Future<SharedPreferences> cachedWindow({int? missing}) async {
    final prefs = await SharedPreferences.getInstance();
    const location = {
      'latitude': 51.5,
      'longitude': -0.1,
      'type': 'coordinates',
      'cityCountry': 'London, UK',
    };
    await prefs.setString('location', jsonEncode(location));
    for (var offset = 0; offset < prayerWindowDays; offset++) {
      if (offset == missing) continue;
      final date = prayerDate(_today, offset);
      final path = (await helper.constructAPIParameters(
        '',
        helper.dateFormatter(date),
        location,
        Future.value(prefs),
      ))!;
      final data = validPrayerTimesResponse();
      data['data']['timings']['Fajr'] = offset == 1 ? '05:12' : '05:00';
      data['data']['date']['gregorian'] = {'date': helper.dateFormatter(date)};
      await prefs.setString(helper.prayerTimesCacheKey(path), jsonEncode(data));
    }
    return prefs;
  }

  test(
    'offline repository reconstructs the actual seven-day saved window',
    () async {
      final prefs = await cachedWindow();
      final savedLocation = prefs.getString('location');
      final window = await loadSavedPrayerWindow(
        cacheOnly: true,
        baseDate: _today,
      );
      expect(window.complete, isTrue);
      expect(window.days, hasLength(7));
      expect(window.days[1].times['Fajr'], DateTime(2026, 10, 8, 5, 12));
      expect(prefs.getString('location'), savedLocation);
      expect(window.configuration, contains('latitude=51.5'));
    },
  );

  test(
    'cache gaps remain incomplete and never skip an unknown day in next event',
    () async {
      await cachedWindow(missing: 1);
      final window = await loadSavedPrayerWindow(
        cacheOnly: true,
        baseDate: _today,
      );
      expect(window.complete, isFalse);
      expect(window.days, hasLength(6));
      expect(
        nextPrayerOccurrence(window.days, DateTime(2026, 10, 7, 22)),
        isNull,
      );
      expect(nextPrayerOccurrence(window.days, _now)!.name, 'Asr');
    },
  );

  test(
    'missing today data prevents a future cache entry from being shown as next prayer',
    () {
      expect(nextPrayerOccurrence([_days().last], _now), isNull);
    },
  );

  test('persisted model rejects normalized invalid dates', () {
    expect(
      () => PrayerDay.fromJson({'date': '2026-02-31', 'timings': _times()}),
      throwsFormatException,
    );
    expect(
      PrayerDay.fromJson(_days().last.toJson()).times['Fajr'],
      DateTime(2026, 10, 8, 5, 12),
    );
  });

  test('alarm horizon is bounded to seven calendar days', () async {
    final prefs = await SharedPreferences.getInstance();
    final backend = _Backend();
    await _update(backend, prefs, [
      for (var offset = 0; offset < 10; offset++)
        PrayerDay(prayerDate(_today, offset), _times()),
    ]);
    expect(backend.alarms, hasLength(33));
    expect(
      backend.alarms.values.every(
        (a) => a.time.isBefore(DateTime(2026, 10, 14)),
      ),
      isTrue,
    );
  });

  test(
    'captured fetch date remains the marker when completion passes midnight',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final capturedDate = prayerDate(DateTime.now(), -1);
      await helper.updateLastFetchedDate(prefs, fetchedDate: capturedDate);
      expect(await helper.shouldFetchDailyData(prefs), isTrue);
      await prefs.setString('last_fetched_date', 'malformed');
      expect(await helper.shouldFetchDailyData(prefs), isTrue);
    },
  );

  test('shared clocks parse display formats and reject invalid times', () {
    expect(prayerTimeOnDate('12:00 AM', _today), DateTime(2026, 10, 7));
    expect(prayerTimeOnDate('12:00 PM', _today), DateTime(2026, 10, 7, 12));
    expect(prayerTimeOnDate('٣:٣٠ م', _today), DateTime(2026, 10, 7, 15, 30));
    expect(prayerTimeOnDate('05:00 (EET)', _today), DateTime(2026, 10, 7, 5));
    for (final invalid in [
      '24:00',
      '99:00',
      '12:60',
      '00:10 AM',
      '13:10 PM',
      '-',
      'bad',
    ]) {
      expect(prayerTimeOnDate(invalid, _today), isNull, reason: invalid);
    }
    expect(() => PrayerDay(_today, {'Fajr': '05:00'}), throwsFormatException);
  });

  test(
    'calendar offset crosses month and year without copying old timings',
    () {
      expect(prayerDate(DateTime(2026, 12, 31, 23), 1), DateTime(2027, 1, 1));
      final days = [
        PrayerDay(DateTime(2026, 12, 31), _times()),
        PrayerDay(DateTime(2027, 1, 1), _times('05:24')),
      ];
      expect(
        nextPrayerOccurrence(days, DateTime(2026, 12, 31, 22))!.time,
        DateTime(2027, 1, 1, 5, 24),
      );
    },
  );

  test('Home and widget use the same actual tomorrow occurrence', () {
    final now = DateTime(2026, 10, 7, 22);
    final occurrence = nextPrayerOccurrence(_days(), now)!;
    final widget = computeNextPrayerState(_days(), now: now)!;
    expect(occurrence.time, DateTime(2026, 10, 8, 5, 12));
    expect(widget.nextPrayerTime, occurrence.time);
    expect(widget.prayerKey, occurrence.name.toLowerCase());
    expect(widget.nextChangeTime, DateTime(2026, 10, 8));
  });

  test('missing tomorrow data never produces a fabricated next Fajr', () {
    final days = [_days().first];
    expect(nextPrayerOccurrence(days, DateTime(2026, 10, 7, 22)), isNull);
    expect(
      computeNextPrayerState(days, now: DateTime(2026, 10, 7, 22)),
      isNull,
    );
  });

  test(
    'event boundary advances after its instant and preserves Sunrise behavior',
    () {
      expect(
        nextPrayerOccurrence(_days(), DateTime(2026, 10, 7, 5))!.name,
        'Fajr',
      );
      expect(
        nextPrayerOccurrence(_days(), DateTime(2026, 10, 7, 5, 0, 1))!.name,
        'Sunrise',
      );
      expect(
        computeNextPrayerState(
          _days(),
          now: DateTime(2026, 10, 7, 4),
        )!.nextChangeTime,
        DateTime(2026, 10, 7, 5, 0, 1),
      );
    },
  );

  test('next event ignores expired dates and sorts unsorted snapshots', () {
    final days = [
      PrayerDay(prayerDate(_today, 1), _times('05:12')),
      PrayerDay(prayerDate(_today, -1), _times('04:40')),
      PrayerDay(_today, _times()),
    ];
    expect(
      nextPrayerOccurrence(days, _now)!.time,
      DateTime(2026, 10, 7, 15, 30),
    );
  });

  test('before Fajr routine ends at todays Fajr, not tomorrow', () {
    final yesterday = PrayerDay(prayerDate(_today, -1), _times('04:50'));
    final window = routinePrayerWindow(
      now: DateTime(2026, 10, 7, 4),
      yesterday: yesterday,
      today: _days().first,
      tomorrow: _days().last,
    );
    expect(window.date, DateTime(2026, 10, 6));
    expect(window.startsAt, DateTime(2026, 10, 6, 4, 50));
    expect(window.endsAt, DateTime(2026, 10, 7, 5));
  });

  test(
    'at Fajr routine begins a new dated interval with actual tomorrow Fajr',
    () {
      final window = routinePrayerWindow(
        now: DateTime(2026, 10, 7, 5),
        today: _days().first,
        tomorrow: _days().last,
      );
      expect(window.date, _today);
      expect(window.endsAt, DateTime(2026, 10, 8, 5, 12));
    },
  );

  test(
    'routine missing or incorrectly dated data leaves boundaries unconfirmed',
    () {
      final window = routinePrayerWindow(
        now: _now,
        today: _days().first,
        tomorrow: PrayerDay(prayerDate(_today, 2), _times()),
      );
      expect(window.endsAt, isNull);
      expect(routinePrayerWindow(now: _now).startsAt, isNull);
    },
  );

  test(
    'prayer API binds offset to captured base date and rejects another response date',
    () async {
      const location = {'latitude': 51.5, 'longitude': -0.1};
      late Uri requested;
      final data = validPrayerTimesResponse();
      data['data']['date']['gregorian'] = {'date': '01-01-2027'};
      final result = await api.getDataFromDay(
        1,
        location,
        baseDate: DateTime(2026, 12, 31),
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(jsonEncode(data), 200);
        }),
      );
      expect(requested.path, '/v1/timings/01-01-2027');
      expect(result['error'], isEmpty);
      expect(
        api.isPrayerTimesResponseForDate(data, DateTime(2027, 1, 2)),
        isFalse,
      );
      data['data']['timings']['Fajr'] = '25:00';
      expect(api.isValidPrayerTimesResponse(data), isFalse);
    },
  );

  test('after Dhuhr alarms include tomorrow Fajr at its actual time', () async {
    final prefs = await SharedPreferences.getInstance();
    final backend = _Backend()..other.add(0);
    expect(await _update(backend, prefs, _days()), isTrue);
    expect(backend.alarms, hasLength(8));
    final fajr = backend.alarms.values.singleWhere((a) => a.name == 'Fajr');
    expect(fajr.time, DateTime(2026, 10, 8, 5, 12));
    expect(backend.alarms.values.any((a) => a.name == 'Sunrise'), isFalse);
    expect(backend.other, {42});
    expect(backend.events.last, 'cancel:0');
  });

  test(
    'failed replacement rolls back staged alarms and preserves committed alarms',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      await _update(backend, prefs, _days());
      final original = Map<int, PrayerAlarm>.from(backend.alarms);
      final manifest = prefs.getString(prayerAlarmManifestKey);
      backend.failAt = backend.schedules + 2;
      expect(
        await _update(
          backend,
          prefs,
          _days(),
          channels: {for (final name in prayerEvents) name: 'new-$name'},
        ),
        isFalse,
      );
      expect(backend.alarms, original);
      expect(prefs.getString(prayerAlarmManifestKey), manifest);
    },
  );

  test(
    'unchanged refresh avoids duplicate scheduling and repairs a missing alarm',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      await _update(backend, prefs, _days());
      final count = backend.schedules;
      await _update(backend, prefs, _days());
      expect(backend.schedules, count);
      backend.alarms.remove(backend.alarms.keys.first);
      await _update(backend, prefs, _days());
      expect(backend.alarms, hasLength(8));
      expect(backend.schedules, greaterThan(count));
    },
  );

  test(
    'disabling one prayer cancels all its dated alarms without requiring network data',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      await _update(backend, prefs, _days());
      await _update(
        backend,
        prefs,
        [],
        enabled: {
          for (final name in prayerEvents)
            name: name != 'Fajr' && name != 'Sunrise',
        },
      );
      expect(backend.alarms.values.any((a) => a.name == 'Fajr'), isFalse);
      expect(backend.alarms, hasLength(7));
      expect(backend.other, {42});
    },
  );

  test(
    'master disable clears prayer-owned alarms and preserves unrelated notifications',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend()..other.addAll([0, 2, 3, 4, 5]);
      await _update(backend, prefs, _days());
      expect(
        await _update(
          backend,
          prefs,
          [],
          enabled: {for (final name in prayerEvents) name: false},
        ),
        isTrue,
      );
      expect(backend.alarms, isEmpty);
      expect(backend.other, {42});
      expect(
        jsonDecode(prefs.getString(prayerAlarmManifestKey)!)['alarms'],
        isEmpty,
      );
    },
  );

  test(
    'partial refresh retains valid future dates for the same configuration',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      await _update(backend, prefs, _days());
      final original = Map<int, PrayerAlarm>.from(backend.alarms);
      expect(await _update(backend, prefs, [_days().first]), isTrue);
      expect(backend.alarms, original);
    },
  );

  test(
    'failed configuration refresh keeps prior alarms; valid replacement retires them',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      await _update(backend, prefs, _days());
      final original = backend.alarms.keys.toSet();
      expect(
        await _update(
          backend,
          prefs,
          [],
          configuration: 'user-selected-method',
        ),
        isFalse,
      );
      expect(backend.alarms.keys.toSet(), original);
      expect(
        await _update(
          backend,
          prefs,
          _days(),
          configuration: 'user-selected-method',
        ),
        isTrue,
      );
      expect(backend.alarms.keys.toSet().intersection(original), isEmpty);
      expect(
        backend.alarms.values.every(
          (a) => a.configuration == 'user-selected-method',
        ),
        isTrue,
      );
    },
  );

  test(
    'changing sound replaces existing occurrences and retires the old channel',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      await _update(backend, prefs, _days());
      await _update(
        backend,
        prefs,
        _days(),
        channels: {
          for (final name in prayerEvents)
            name: name == 'Fajr' ? 'new-fajr-sound' : 'channel-$name',
        },
        sounds: {
          for (final name in prayerEvents)
            name: name == 'Fajr' ? 'adhan' : null,
        },
      );
      final fajr = backend.alarms.values.singleWhere((a) => a.name == 'Fajr');
      expect(fajr.sound, 'adhan');
      expect(fajr.channelId, 'new-fajr-sound');
      expect(backend.alarms, hasLength(8));
    },
  );

  test(
    'simultaneous reconciliations wait and apply the newer configuration last',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final blocked = Completer<void>();
      final backend = _Backend()..blocked = blocked;
      final first = _update(backend, prefs, _days());
      while (backend.schedules == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final second = _update(backend, prefs, _days(), configuration: 'updated');
      await Future<void>.delayed(Duration.zero);
      expect(backend.schedules, 1);
      blocked.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(
        backend.alarms.values.every((a) => a.configuration == 'updated'),
        isTrue,
      );
    },
  );

  test(
    'saved notification preferences do not alter the selected prayer location',
    () async {
      const location =
          '{"latitude":51.5,"longitude":-0.1,"cityCountry":"London, UK"}';
      SharedPreferences.setMockInitialValues({
        'location': location,
        'prayerNotification': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      expect(
        await helper.handleNotifications(
          Future.value(prefs),
          _days(),
          configuration: 'saved-config',
          backend: backend,
          now: _now,
        ),
        isTrue,
      );
      expect(prefs.getString('location'), location);
      expect(backend.alarms, hasLength(8));
    },
  );

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  for (final failures in [
    <String>[],
    ['exact_alarms_not_permitted'],
    ['invalid_sound', 'exact_alarms_not_permitted'],
    ['exact_alarms_not_permitted', 'invalid_sound'],
  ]) {
    test(
      'native one-time schedule handles fallback sequence $failures',
      () async {
        // The notification plugin validates against the real clock before
        // invoking the mocked platform channel.
        final scheduledAt = prayerDate(
          DateTime.now(),
          1,
        ).add(const Duration(hours: 5, minutes: 12));
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        AndroidFlutterLocalNotificationsPlugin.registerWith();
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final attempts = <Map<String, dynamic>>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'initialize') return true;
              if (call.method == 'zonedSchedule') {
                attempts.add(Map<String, dynamic>.from(call.arguments as Map));
                if (attempts.length <= failures.length) {
                  throw PlatformException(code: failures[attempts.length - 1]);
                }
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        expect(
          await NotificationService().schedulePrayerOccurrence(
            scheduledAt,
            123,
            'sound-channel',
            'Fajr',
            'Reminder',
            playSound: true,
            soundResourceName: 'adhan',
          ),
          isEmpty,
        );
        expect(attempts, hasLength(failures.length + 1));
        expect(
          attempts.every((args) => args['matchDateTimeComponents'] == null),
          isTrue,
        );
        expect(
          DateTime.parse(
            attempts.last['scheduledDateTimeISO8601'] as String,
          ).isAtSameMomentAs(scheduledAt),
          isTrue,
        );
        if (failures.contains('exact_alarms_not_permitted')) {
          expect(
            attempts.last['platformSpecifics']['scheduleMode'],
            'inexactAllowWhileIdle',
          );
        }
        if (failures.contains('invalid_sound')) {
          expect(attempts.last['platformSpecifics']['playSound'], isFalse);
        }
      },
    );
  }
}
