import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/prayer_notifications/prayer_alert_options_editor.dart';
import 'package:muslim/UI/prayer_notifications/prayer_notifications.dart';
import 'package:muslim/shared/constants.dart';
import 'package:muslim/utils/helper.dart' as helper;
import 'package:muslim/utils/notification_service.dart';
import 'package:muslim/utils/prayer_alarm_scheduler.dart';
import 'package:muslim/utils/prayer_alert_options.dart';
import 'package:muslim/utils/prayer_notification_status.dart';
import 'package:muslim/utils/prayer_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/daily_use_test_host.dart';

class _Backend implements PrayerAlarmBackend {
  final alarms = <int, PrayerAlarm>{};
  bool failReminder = false;
  @override
  Future<void> schedule(PrayerAlarm alarm) async {
    if (failReminder && alarm.isReminder) throw StateError('Rejected reminder');
    alarms[alarm.id] = alarm;
  }

  @override
  Future<void> cancel(int id) async => alarms.remove(id);
  @override
  Future<Set<int>> pendingIds() async => alarms.keys.toSet();
}

PrayerDay _day(DateTime date, {String fajr = '05:00'}) => PrayerDay(date, {
  'Fajr': fajr,
  'Sunrise': '06:30',
  'Dhuhr': '12:00',
  'Asr': '15:00',
  'Maghrib': '18:00',
  'Isha': '20:00',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeDailyUseTests();
  final now = DateTime(2026, 10, 30, 1);

  test(
    'all selectable bundled prayer sounds are available and retained on Android',
    () {
      final keepXml = File(
        'android/app/src/main/res/raw/keep.xml',
      ).readAsStringSync();
      final retained = RegExp(
        r'@raw/([a-z0-9_]+)',
      ).allMatches(keepXml).map((match) => match.group(1)!).toSet();
      for (final directory in [
        Directory('assets/adhan'),
        Directory('assets/reminders'),
      ]) {
        if (!directory.existsSync()) continue;
        for (final sound in directory.listSync().whereType<File>().where(
          (file) => file.path.toLowerCase().endsWith('.mp3'),
        )) {
          final resourceName = androidRawResourceNameFromAssetPath(
            sound.path.replaceAll('\\', '/'),
          );
          final raw = File('android/app/src/main/res/raw/$resourceName.mp3');
          expect(
            raw.existsSync(),
            isTrue,
            reason: '${sound.path} needs an Android raw resource',
          );
          expect(
            retained,
            contains(resourceName),
            reason: '${sound.path} must survive release resource shrinking',
          );
          expect(
            raw.readAsBytesSync(),
            orderedEquals(sound.readAsBytesSync()),
            reason: 'Preview and scheduled audio must use the same recording',
          );
        }
      }
    },
  );

  Future<bool> reconcile(
    _Backend backend,
    SharedPreferences prefs, {
    Map<String, PrayerAlertOptions> options = const {},
    List<PrayerDay>? days,
    Map<String, bool>? enabled,
  }) => PrayerAlarmReconciler(prefs, backend).reconcile(
    days: days ?? [_day(DateTime(2026, 10, 30)), _day(DateTime(2026, 10, 31))],
    configuration: 'saved-location',
    now: now,
    enabled:
        enabled ?? {for (final name in PRAYER_NOTIFICATION_NAMES) name: true},
    channels: {
      for (final name in PRAYER_NOTIFICATION_NAMES) name: 'channel-$name',
    },
    sounds: {
      for (final name in PRAYER_NOTIFICATION_NAMES) name: 'adhan_makkah',
    },
    options: options,
    reminderBodies: const {'Fajr': 'Prepare for Fajr'},
  );

  test(
    'existing preferences retain notification audio and no reminders',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      expect(await reconcile(backend, prefs), isTrue);
      expect(backend.alarms, hasLength(10));
      expect(
        backend.alarms.values.every(
          (a) => !a.forceSound && a.volume == null && !a.isReminder,
        ),
        isTrue,
      );
    },
  );

  test(
    'reminders inherit their prayer audio settings and keep their own sound',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      expect(
        await reconcile(
          backend,
          prefs,
          options: const {
            'Fajr': PrayerAlertOptions(
              forceSound: true,
              volume: .35,
              reminderEnabled: true,
              reminderMinutes: 15,
              reminderSound: 'adhan_madinah_short',
            ),
          },
        ),
        isTrue,
      );
      final reminders = backend.alarms.values
          .where((a) => a.isReminder)
          .toList();
      expect(reminders, hasLength(2));
      expect(reminders.first.time, DateTime(2026, 10, 30, 4, 45));
      expect(reminders.first.body, 'Prepare for Fajr');
      expect(reminders.first.sound, 'adhan_madinah_short');
      expect(reminders.first.forceSound, isTrue);
      expect(reminders.first.volume, .35);
      final fajr = backend.alarms.values.firstWhere(
        (a) => a.name == 'Fajr' && !a.isReminder,
      );
      expect(fajr.forceSound, isTrue);
      expect(fajr.volume, .35);
      expect(
        backend.alarms.values
            .where((a) => a.name != 'Fajr')
            .every((a) => a.volume == null && !a.forceSound),
        isTrue,
      );
      expect(backend.alarms.keys.every(isOwnedPrayerAlarm), isTrue);
    },
  );

  test(
    'reminders crossing midnight retain prayer dates on partial refresh',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      final days = [
        _day(DateTime(2026, 10, 30)),
        _day(DateTime(2026, 10, 31), fajr: '00:10'),
      ];
      const options = {
        'Fajr': PrayerAlertOptions(reminderEnabled: true, reminderMinutes: 30),
      };
      await reconcile(backend, prefs, days: days, options: options);
      final reminder = backend.alarms.values.singleWhere(
        (a) => a.isReminder && a.occurrenceTime.day == 31,
      );
      expect(reminder.time, DateTime(2026, 10, 30, 23, 40));
      final signatures = backend.alarms.values.map((a) => a.signature).toSet();
      await reconcile(backend, prefs, days: [days.first], options: options);
      expect(backend.alarms.values.map((a) => a.signature).toSet(), signatures);
      expect(
        PrayerAlarm.fromJson(reminder.toJson()).occurrenceTime,
        reminder.occurrenceTime,
      );
    },
  );

  test(
    'elapsed reminders are skipped while the upcoming prayer is kept',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      await reconcile(
        backend,
        prefs,
        days: [_day(DateTime(2026, 10, 30), fajr: '01:05')],
        options: const {'Fajr': PrayerAlertOptions(reminderEnabled: true)},
      );
      expect(
        backend.alarms.values.any((a) => a.name == 'Fajr' && !a.isReminder),
        isTrue,
      );
      expect(backend.alarms.values.any((a) => a.isReminder), isFalse);
    },
  );

  test('turning a reminder off cancels it even without cached days', () async {
    final prefs = await SharedPreferences.getInstance();
    final backend = _Backend();
    await reconcile(
      backend,
      prefs,
      options: const {'Fajr': PrayerAlertOptions(reminderEnabled: true)},
    );
    expect(backend.alarms, hasLength(12));
    await reconcile(backend, prefs, days: []);
    expect(backend.alarms, hasLength(10));
    expect(backend.alarms.values.any((a) => a.isReminder), isFalse);
  });

  test(
    'failed reminder staging preserves the committed prayer alarms',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      await reconcile(backend, prefs);
      final original = Map<int, PrayerAlarm>.of(backend.alarms);
      final manifest = prefs.getString(prayerAlarmManifestKey);
      backend.failReminder = true;
      expect(
        await reconcile(
          backend,
          prefs,
          options: const {'Fajr': PrayerAlertOptions(reminderEnabled: true)},
        ),
        isFalse,
      );
      expect(backend.alarms, original);
      expect(prefs.getString(prayerAlarmManifestKey), manifest);
    },
  );

  test(
    'audio and reminder edits replace alarms; prayer disable removes both',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      await reconcile(
        backend,
        prefs,
        options: const {'Fajr': PrayerAlertOptions(reminderEnabled: true)},
      );
      final originalIds = backend.alarms.keys.toSet();
      await reconcile(
        backend,
        prefs,
        options: const {
          'Fajr': PrayerAlertOptions(
            forceSound: true,
            volume: .5,
            reminderEnabled: true,
            reminderMinutes: 20,
          ),
        },
      );
      expect(backend.alarms.keys.toSet().intersection(originalIds), isEmpty);
      expect(
        backend.alarms.values
            .firstWhere((a) => a.name == 'Fajr' && !a.isReminder)
            .volume,
        .5,
      );
      await reconcile(
        backend,
        prefs,
        days: [],
        enabled: {
          for (final name in PRAYER_NOTIFICATION_NAMES) name: name != 'Fajr',
        },
      );
      expect(backend.alarms.values.any((a) => a.name == 'Fajr'), isFalse);
      await reconcile(
        backend,
        prefs,
        days: [],
        enabled: {for (final name in PRAYER_NOTIFICATION_NAMES) name: false},
      );
      expect(backend.alarms, isEmpty);
    },
  );

  test('saved custom reminder text and settings reach the scheduler', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayerNotification', true);
    await prefs.setString(
      prayerNotificationModePreferenceKey('Fajr'),
      prayerNotificationModeCustomSound,
    );
    await prefs.setString(
      prayerNotificationSoundPreferenceKey('Fajr'),
      'adhan_makkah',
    );
    await prefs.setString(
      prayerAlertOptionsKey('Fajr'),
      jsonEncode(
        const PrayerAlertOptions(
          forceSound: true,
          volume: .25,
          reminderEnabled: true,
          reminderText: 'Time to make wudu',
          reminderSound: 'silent',
        ).toJson(),
      ),
    );
    final backend = _Backend();
    expect(
      await helper.handleNotifications(
        Future.value(prefs),
        [_day(DateTime(2026, 10, 30))],
        backend: backend,
        now: now,
        configuration: 'saved-location',
      ),
      isTrue,
    );
    final reminder = backend.alarms.values.singleWhere((a) => a.isReminder);
    expect(reminder.body, 'Time to make wudu');
    expect(reminder.sound, isNull);
    expect(reminder.forceSound, isFalse);
    expect(reminder.volume, isNull);
    final confirmed = confirmedPrayerAlarms(
      prefs,
      backend.alarms.keys.toSet(),
      configuration: 'saved-location',
      now: now,
    );
    expect(confirmed.first.isReminder, isTrue);
    expect(confirmed.first.body, 'Time to make wudu');
  });

  test(
    'independent Adhan audio routes to native scheduling with localized controls',
    () async {
      const channel = MethodChannel('com.bplusplus.muslim/prayer_audio');
      MethodCall? scheduled;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        scheduled = call;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await NotificationService().schedule(
        PrayerAlarm(
          id: 123,
          name: 'Fajr',
          time: now,
          configuration: 'current',
          channelId: 'fajr',
          sound: 'adhan_makkah',
          forceSound: true,
          volume: .4,
        ),
      );
      expect(scheduled!.method, 'schedule');
      expect((scheduled!.arguments as Map)['forceSound'], isTrue);
      expect((scheduled!.arguments as Map)['volume'], .4);
      expect((scheduled!.arguments as Map)['stopLabel'], isNotEmpty);
    },
  );

  test(
    'old playback manifests are replaced when installing stoppable prayer audio',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      await reconcile(backend, prefs);
      final manifest =
          jsonDecode(prefs.getString(prayerAlarmManifestKey)!)
              as Map<String, dynamic>;
      for (final alarm in manifest['alarms'] as List) {
        (alarm as Map).remove('deliveryVersion');
      }
      await prefs.setString(prayerAlarmManifestKey, jsonEncode(manifest));
      final ids = backend.alarms.keys.toSet();
      await reconcile(backend, prefs);
      expect(ids.intersection(backend.alarms.keys.toSet()), isEmpty);
      expect(
        backend.alarms.values.every(
          (alarm) => alarm.deliveryVersion == prayerAudioDeliveryVersion,
        ),
        isTrue,
      );
    },
  );

  for (final sound in ['quick_allah_akbar', 'system']) {
    test(
      'forced reminder with $sound uses native audio with inherited volume',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('prayerNotification', true);
        await prefs.setString(
          prayerAlertOptionsKey('Fajr'),
          jsonEncode(
            PrayerAlertOptions(
              forceSound: true,
              volume: .3,
              reminderEnabled: true,
              reminderSound: sound,
            ).toJson(),
          ),
        );
        final backend = _Backend();
        await helper.handleNotifications(
          Future.value(prefs),
          [_day(DateTime(2026, 10, 30))],
          backend: backend,
          now: now,
          configuration: 'saved-location',
        );
        final alarm = backend.alarms.values.singleWhere(
          (alarm) => alarm.isReminder,
        );
        expect(alarm.forceSound, isTrue);
        expect(alarm.volume, .3);
        expect(
          confirmedPrayerAlarms(
            prefs,
            backend.alarms.keys.toSet(),
            configuration: 'saved-location',
            now: now,
          ).first.isReminder,
          isTrue,
        );
        const channel = MethodChannel('com.bplusplus.muslim/prayer_audio');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        Map? scheduled;
        messenger.setMockMethodCallHandler(channel, (call) async {
          scheduled = call.arguments as Map;
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        await NotificationService().schedule(alarm);
        expect(scheduled!['sound'], sound);
        expect(scheduled!['forceSound'], isTrue);
        expect(scheduled!['volume'], .3);
        expect(
          scheduled!['title'],
          'Prayer_Reminder_Title'.tr(namedArgs: {'prayer': 'Fajr'.tr()}),
        );
      },
    );
  }

  for (final force in [false, true]) {
    test(
      'denied exact audio access preserves ordinary fallback with force=$force',
      () async {
        const native = MethodChannel('com.bplusplus.muslim/prayer_audio');
        const notifications = MethodChannel(
          'dexterous.com/flutter/local_notifications',
        );
        AndroidFlutterLocalNotificationsPlugin.registerWith();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final attempts = <Map>[];
        messenger.setMockMethodCallHandler(native, (_) async {
          throw PlatformException(code: 'exact_alarms_not_permitted');
        });
        messenger.setMockMethodCallHandler(notifications, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'zonedSchedule') {
            attempts.add(call.arguments as Map);
            if (attempts.length == 1) {
              throw PlatformException(code: 'exact_alarms_not_permitted');
            }
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(native, null);
          messenger.setMockMethodCallHandler(notifications, null);
        });
        final scheduled = NotificationService().schedule(
          PrayerAlarm(
            id: 123,
            name: 'Fajr',
            time: DateTime.now().add(const Duration(days: 1)),
            configuration: 'current',
            channelId: 'fajr',
            sound: 'quick_allah_akbar',
            forceSound: force,
          ),
        );
        if (force) {
          await expectLater(scheduled, throwsA(isA<PlatformException>()));
          expect(attempts, isEmpty);
        } else {
          await scheduled;
          expect(attempts, hasLength(2));
          expect(
            attempts.last['platformSpecifics']['scheduleMode'],
            'inexactAllowWhileIdle',
          );
          expect(attempts.last['platformSpecifics']['playSound'], isTrue);
        }
      },
    );
  }

  testWidgets(
    'stop audio stays available while prayer alarms are being refreshed',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final refresh = Completer<bool>();
      var stops = 0;
      await pumpDailyPage(
        tester,
        PrayerNotificationsPageClass(
          prefs: Future.value(prefs),
          loadStatus: () async =>
              const PrayerNotificationStatus(notifications: true),
          reconcile: () => refresh.future,
          stopAudio: () async {
            stops++;
          },
        ),
        scale: 1,
      );
      final prayerSwitch = find.byKey(const ValueKey('prayer_switch_Fajr'));
      await tester.ensureVisible(prayerSwitch);
      await tester.tap(prayerSwitch);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final stop = find.byKey(const ValueKey('stop_prayer_audio'));
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      await tester.pump();
      expect(stops, 1);
      expect(refresh.isCompleted, isFalse);
      refresh.complete(true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'default reminder sound uses system sound, never a raw resource named system',
    () async {
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Map? scheduled;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'zonedSchedule') scheduled = call.arguments as Map;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await NotificationService().schedule(
        PrayerAlarm(
          id: 123,
          name: 'Fajr',
          time: DateTime.now().add(const Duration(days: 1)),
          configuration: 'current',
          channelId: 'reminder',
          sound: 'system',
          isReminder: true,
          body: 'Prepare',
        ),
      );
      expect(scheduled!['platformSpecifics']['playSound'], isTrue);
      expect(scheduled!['platformSpecifics']['sound'], isNull);
    },
  );

  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    testWidgets(
      'reminder custom inputs validate and controls fit at 3x text in $locale',
      (tester) async {
        var options = const PrayerAlertOptions(
          volume: .5,
          forceSound: true,
          reminderEnabled: true,
        );
        await pumpDailyPage(
          tester,
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SingleChildScrollView(
                child: PrayerAlertOptionsEditor(
                  options: options,
                  adhanEnabled: true,
                  enabled: true,
                  sounds: const {'adhan_makkah': 'Makkah'},
                  onPreview: (_) async {},
                  onChanged: (changes) async => setState(
                    () => options = PrayerAlertOptions.fromJson({
                      ...options.toJson(),
                      ...changes,
                    }),
                  ),
                ),
              ),
            ),
          ),
          locale: locale,
          scale: 3,
        );
        final custom = find.byType(DropdownButtonFormField<String>).first;
        await tester.ensureVisible(custom);
        await tester.tap(custom);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Prayer_Reminder_Custom'.tr()),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Prayer_Reminder_Custom'.tr()).last);
        await tester.pumpAndSettle();
        final input = find.byKey(const ValueKey('reminder_custom_minutes'));
        await tester.enterText(input, '0');
        await tester.tap(find.text('Prayer_Alert_Save'.tr()));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.enterText(input, '27');
        await tester.tap(find.text('Prayer_Alert_Save'.tr()));
        await tester.pumpAndSettle();
        expect(options.reminderMinutes, 27);
        final messageDropdown = find
            .byType(DropdownButtonFormField<String>)
            .at(1);
        await tester.ensureVisible(messageDropdown);
        await tester.tap(messageDropdown);
        await tester.pumpAndSettle();
        final customText = find.text('Prayer_Reminder_Custom_Text'.tr());
        await tester.scrollUntilVisible(
          customText,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(customText.last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Prayer_Alert_Cancel'.tr()));
        await tester.pumpAndSettle();
        expect(options.reminderText, reminderPrepareText);
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>).at(1),
              )
              .initialValue,
          reminderPrepareText,
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          customText,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(customText.last);
        await tester.pumpAndSettle();
        final textInput = find.byKey(const ValueKey('reminder_custom_text'));
        await tester.enterText(textInput, ' ');
        await tester.tap(find.text('Prayer_Alert_Save'.tr()));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.enterText(textInput, 'Make wudu before prayer');
        await tester.tap(find.text('Prayer_Alert_Save'.tr()));
        await tester.pumpAndSettle();
        expect(options.reminderText, 'Make wudu before prayer');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'prayer options persist independently and reconcile in $locale',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        var reconciles = 0;
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
          ),
          locale: locale,
          scale: 1,
        );
        final tile = find.byKey(const PageStorageKey('prayer_options_Fajr'));
        await tester.ensureVisible(tile);
        await tester.tap(
          find.descendant(of: tile, matching: find.text('Fajr'.tr())).first,
        );
        await tester.pumpAndSettle();
        final reminderSwitch = find
            .descendant(of: tile, matching: find.byType(SwitchListTile))
            .last;
        await tester.ensureVisible(reminderSwitch);
        await tester.tap(reminderSwitch);
        await tester.pumpAndSettle();
        expect(PrayerAlertOptions.read(prefs, 'Fajr').reminderEnabled, isTrue);
        expect(PrayerAlertOptions.read(prefs, 'Isha').reminderEnabled, isFalse);
        expect(reconciles, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
