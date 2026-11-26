import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/utils/helper.dart' as helper;
import 'package:muslim/utils/notification_service.dart';
import 'package:muslim/utils/prayer_alarm_scheduler.dart';
import 'package:muslim/utils/prayer_alert_options.dart';
import 'package:muslim/utils/prayer_notification_status.dart';
import 'package:muslim/utils/prayer_notification_text.dart';
import 'package:muslim/utils/prayer_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backend implements PrayerAlarmBackend {
  final alarms = <int, PrayerAlarm>{};
  int schedules = 0;
  @override
  Future<void> schedule(PrayerAlarm alarm) async {
    schedules++;
    alarms[alarm.id] = alarm;
  }

  @override
  Future<void> cancel(int id) async => alarms.remove(id);
  @override
  Future<Set<int>> pendingIds() async => alarms.keys.toSet();
}

final _today = DateTime(2026, 11, 1);
final _now = DateTime(2026, 11, 1, 1);
PrayerDay _day(DateTime date) => PrayerDay(date, {
  'Fajr': '05:00',
  'Sunrise': '06:30',
  'Dhuhr': '12:00',
  'Asr': '15:00',
  'Maghrib': '18:00',
  'Isha': '20:00',
});
final _days = [_day(_today), _day(DateTime(2026, 11, 2))];

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // Deliberately never initialize EasyLocalization or mount its widget. This is
  // the state of the background engine that refreshes alarms after midnight.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<SharedPreferences> preferences(
    String locale, {
    bool force = true,
    String text = reminderPreviousText,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
    await prefs.setBool('prayerNotification', true);
    await prefs.setString(
      prayerAlertOptionsKey('Fajr'),
      jsonEncode(
        PrayerAlertOptions(
          reminderEnabled: true,
          reminderText: text,
          reminderSound: 'quick_allah_akbar',
          forceSound: force,
        ).toJson(),
      ),
    );
    return prefs;
  }

  Future<bool> refresh(
    SharedPreferences prefs,
    _Backend backend, {
    List<PrayerDay>? days,
  }) => helper.handleNotifications(
    Future.value(prefs),
    days ?? _days,
    backend: backend,
    now: _now,
    configuration: 'saved-configuration',
  );

  for (final locale in ['en_US', 'ar_EG']) {
    final arabic = locale == 'ar_EG';
    final title = arabic ? 'تذكير قبل صلاة فجر' : 'Reminder before Fajr';
    final previousBody = arabic
        ? 'باقٍ 10 دقيقة على صلاة فجر. إذا لم تصلِّ الصلاة السابقة فتذكّر أداءها.'
        : 'Fajr is in 10 minutes. If you have not prayed the previous salah, remember to pray it.';

    test(
      'headless next-day reminder uses saved $locale for body, title and native controls',
      () async {
        final prefs = await preferences(locale);
        final backend = _Backend();
        expect(await refresh(prefs, backend), isTrue);
        final reminders = backend.alarms.values
            .where((alarm) => alarm.isReminder)
            .toList();
        expect(reminders, hasLength(2));
        final tomorrow = reminders.singleWhere(
          (alarm) => alarm.occurrenceTime.day == 2,
        );
        expect(tomorrow.time, DateTime(2026, 11, 2, 4, 50));
        expect(tomorrow.title, title);
        expect(tomorrow.body, previousBody);
        expect(tomorrow.locale, locale.replaceAll('_', '-'));
        final persisted = PrayerAlarm.fromJson(tomorrow.toJson());
        expect(persisted.title, title);
        expect(persisted.body, previousBody);

        const channel = MethodChannel('com.bplusplus.muslim/prayer_audio');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        Map? payload;
        messenger.setMockMethodCallHandler(channel, (call) async {
          payload = call.arguments as Map;
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        // The captured alarm language also controls Stop, even if preferences
        // change between staging an alarm and handing it to the native scheduler.
        await prefs.setString('locale', arabic ? 'en_US' : 'ar_EG');
        await NotificationService().schedule(persisted);
        expect(payload!['title'], title);
        expect(payload!['body'], previousBody);
        final messages =
            jsonDecode(
                  File(
                    'assets/translations/${persisted.locale}.json',
                  ).readAsStringSync(),
                )
                as Map;
        expect(payload!['stopLabel'], messages['Audio_Stop']);
        expect(payload!['stopHint'], messages['Prayer_Audio_Stop_Hint']);
        expect(payload!['channelName'], messages['Prayer_Adhan_Playback']);
      },
    );

    test(
      'headless notification-only reminder is localized in $locale',
      () async {
        final prefs = await preferences(locale, force: false);
        final backend = _Backend();
        expect(await refresh(prefs, backend), isTrue);
        final tomorrow = backend.alarms.values.singleWhere(
          (alarm) => alarm.isReminder && alarm.occurrenceTime.day == 2,
        );
        AndroidFlutterLocalNotificationsPlugin.registerWith();
        const channel = MethodChannel(
          'dexterous.com/flutter/local_notifications',
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        Map? payload;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'zonedSchedule') payload = call.arguments as Map;
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        // The notification plugin rejects past dates before calling Android.
        await NotificationService().schedule(
          PrayerAlarm.fromJson({
            ...tomorrow.toJson(),
            'epoch': DateTime.now()
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch,
          }),
        );
        expect(payload!['title'], title);
        expect(payload!['body'], previousBody);
      },
    );

    test(
      'headless prepare preset and custom message retain the right text in $locale',
      () async {
        final prefs = await preferences(locale, text: reminderPrepareText);
        final backend = _Backend();
        await refresh(prefs, backend);
        final expected = arabic
            ? 'باقٍ 10 دقيقة على صلاة فجر. استعد للصلاة.'
            : 'Fajr is in 10 minutes. Get ready for prayer.';
        expect(
          backend.alarms.values.firstWhere((alarm) => alarm.isReminder).body,
          expected,
        );
        const custom = 'Custom reminder: keep {prayer} exactly as written.';
        await prefs.setString(
          prayerAlertOptionsKey('Fajr'),
          jsonEncode(
            const PrayerAlertOptions(
              reminderEnabled: true,
              reminderText: custom,
            ).toJson(),
          ),
        );
        await refresh(prefs, backend);
        final reminder = backend.alarms.values.firstWhere(
          (alarm) => alarm.isReminder,
        );
        expect(reminder.title, title);
        expect(reminder.body, custom);
        expect(
          confirmedPrayerAlarms(
            prefs,
            backend.alarms.keys.toSet(),
            configuration: 'saved-configuration',
            now: _now,
          ).first.isReminder,
          isTrue,
        );
      },
    );
  }

  test(
    'refresh repairs raw translation keys on an existing future cached day',
    () async {
      final prefs = await preferences('en_US');
      final backend = _Backend();
      await refresh(prefs, backend);
      final manifest =
          jsonDecode(prefs.getString(prayerAlarmManifestKey)!) as Map;
      for (final raw in manifest['alarms'] as List) {
        final alarm = raw as Map;
        alarm.remove('locale');
        alarm['title'] = alarm['isReminder'] == true
            ? 'Prayer_Reminder_Title'
            : null;
        if (alarm['isReminder'] == true) alarm['body'] = reminderPreviousText;
      }
      await prefs.setString(prayerAlarmManifestKey, jsonEncode(manifest));
      final oldIds = backend.alarms.keys.toSet();
      // Only today was loaded; tomorrow must be rebuilt from the old manifest.
      expect(await refresh(prefs, backend, days: [_days.first]), isTrue);
      expect(oldIds.intersection(backend.alarms.keys.toSet()), isEmpty);
      final tomorrow = backend.alarms.values.singleWhere(
        (alarm) => alarm.isReminder && alarm.occurrenceTime.day == 2,
      );
      expect(tomorrow.title, 'Reminder before Fajr');
      expect(
        tomorrow.body,
        contains('If you have not prayed the previous salah'),
      );
      final schedules = backend.schedules;
      await refresh(prefs, backend);
      expect(backend.schedules, schedules);
    },
  );

  test(
    'locale selection follows the saved app language, then device language and English fallback',
    () async {
      final prefs = await SharedPreferences.getInstance();
      binding.platformDispatcher.localeTestValue = const Locale('ar', 'EG');
      addTearDown(binding.platformDispatcher.clearLocaleTestValue);
      expect(PrayerNotificationText.localeFor(prefs), 'ar-EG');
      await prefs.setString('locale', 'en_US');
      expect(PrayerNotificationText.localeFor(prefs), 'en-US');
      await prefs.setString('locale', 'ar-SA');
      expect(PrayerNotificationText.localeFor(prefs), 'ar-EG');
      await prefs.setString('locale', 'fr_FR');
      expect(PrayerNotificationText.localeFor(prefs), 'en-US');
    },
  );
}
