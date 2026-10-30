import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'prayer_alarm_scheduler.dart';
import 'package:prayer_audio/prayer_audio.dart';

class NotificationService implements PrayerAlarmBackend {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  @override
  Future<Set<int>> pendingIds() async {
    await init();
    return (await _notificationsPlugin.pendingNotificationRequests().timeout(
          const Duration(seconds: 10),
        ))
        .map((request) => request.id)
        .toSet()
        .union(
          !kIsWeb && Platform.isAndroid
              ? await PrayerAudio.pendingIds()
              : <int>{},
        );
  }

  @override
  Future<void> cancel(int id) => clearNotification(id);

  @override
  Future<void> schedule(PrayerAlarm alarm) async {
    final body =
        alarm.body ?? "${"Don't forget praying".tr()} ${alarm.name.tr()}";
    final independentAudio = alarm.forceSound || alarm.volume != null;
    if (alarm.sound != null && (!alarm.isReminder || independentAudio)) {
      try {
        await PrayerAudio.schedule({
          ...alarm.toJson(),
          'title': alarm.isReminder
              ? 'Prayer_Reminder_Title'.tr(
                  namedArgs: {'prayer': alarm.name.tr()},
                )
              : alarm.name.tr(),
          'body': body,
          'stopLabel': 'Audio_Stop'.tr(),
          'channelName': 'Prayer_Adhan_Playback'.tr(),
          'stopHint': 'Prayer_Audio_Stop_Hint'.tr(),
        });
        return;
      } on PlatformException catch (error) {
        // Ordinary prayer sounds keep the existing inexact notification fallback
        // when exact alarms are unavailable. Independent audio needs exact access.
        if (independentAudio || error.code != 'exact_alarms_not_permitted') {
          rethrow;
        }
      }
    }
    final error = await schedulePrayerOccurrence(
      alarm.time,
      alarm.id,
      alarm.channelId,
      alarm.isReminder
          ? 'Prayer_Reminder_Title'.tr(namedArgs: {'prayer': alarm.name.tr()})
          : alarm.name.tr(),
      body,
      playSound: alarm.sound != null,
      soundResourceName: alarm.sound == 'system' ? null : alarm.sound,
    );
    if (error.isNotEmpty) throw StateError(error);
  }

  Future<void> stopPrayerAudio() async {
    if (!kIsWeb && Platform.isAndroid) await PrayerAudio.stop();
  }

  Future<void> clearAllNotifications() async {
    for (final id
        in !kIsWeb && Platform.isAndroid
            ? await PrayerAudio.pendingIds()
            : <int>{}) {
      await PrayerAudio.cancel(id);
    }
    await _notificationsPlugin.cancelAll();
  }

  Future<void> clearNotification(int id) async {
    if (!kIsWeb && Platform.isAndroid) await PrayerAudio.cancel(id);
    await _notificationsPlugin
        .cancel(id: id)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    tz.initializeTimeZones();
    // final String currentTimeZone = DateTime.now().timeZoneName;
    // tz.setLocalLocation(tz.getLocation("Europe/London"));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin
        .initialize(settings: initializationSettings)
        .timeout(const Duration(seconds: 10));
    _initialized = true;
  }

  Future<bool> requestExactAlarmPermissionIfNeeded() async {
    await init();
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin == null) {
      return false;
    }
    final bool canScheduleExact =
        await androidPlugin.canScheduleExactNotifications() ?? false;
    if (canScheduleExact) {
      return true;
    }
    return await androidPlugin.requestExactAlarmsPermission() ?? false;
  }

  Future<(bool?, bool?)> readPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return (null, null);
    await init();
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return (
      await android?.areNotificationsEnabled(),
      await android?.canScheduleExactNotifications(),
    );
  }

  Future<void> showTestNotification(String title, String body) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError('Android notifications');
    }
    await init();
    final (granted, _) = await readPermissions();
    if (granted != true) throw StateError('Notification permission required');
    await _notificationsPlugin
        .show(
          id: 900000,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'app_test_notification_v1',
              'Notifications_Test'.tr(),
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<String> schedulePrayerOccurrence(
    DateTime selectedTime,
    int zoneId,
    String channelId,
    String title,
    String body, {
    bool playSound = false,
    String? soundResourceName,
    bool enableVibration = true,
  }) async {
    await init();
    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(
      selectedTime,
      tz.local,
    );

    var mode = AndroidScheduleMode.exactAllowWhileIdle;
    var effectiveSound = playSound;
    var effectiveChannel = channelId;
    // Retry independently: an unavailable sound and denied exact permission
    // can occur together. Every attempt remains a one-time dated alarm.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _notificationsPlugin
            .zonedSchedule(
              id: zoneId,
              title: title,
              body: body,
              scheduledDate: scheduledTime,
              notificationDetails: _notificationDetails(
                effectiveChannel,
                title,
                body,
                selectedTime,
                playSound: effectiveSound,
                soundResourceName: effectiveSound ? soundResourceName : null,
                enableVibration: enableVibration,
              ),
              androidScheduleMode: mode,
            )
            .timeout(const Duration(seconds: 5));
        return '';
      } on PlatformException catch (error) {
        if (error.code == 'invalid_sound' && effectiveSound) {
          effectiveSound = false;
          effectiveChannel = '${channelId}_fallback';
          continue;
        }
        if (error.code == 'exact_alarms_not_permitted' &&
            mode == AndroidScheduleMode.exactAllowWhileIdle) {
          mode = AndroidScheduleMode.inexactAllowWhileIdle;
          continue;
        }
        debugPrint('Prayer occurrence scheduling failed: $error');
        return 'Prayer occurrence scheduling failed: $error';
      } catch (error) {
        debugPrint('Prayer occurrence scheduling failed: $error');
        return 'Prayer occurrence scheduling failed: $error';
      }
    }
    return 'Prayer occurrence scheduling failed after fallback attempts';
  }

  NotificationDetails _notificationDetails(
    String id,
    String title,
    String body,
    DateTime selectedTime, {
    required bool playSound,
    String? soundResourceName,
    required bool enableVibration,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        title,
        channelDescription: body,
        importance: Importance.max,
        priority: Priority.high,
        playSound: playSound,
        sound: playSound && soundResourceName != null && soundResourceName != ''
            ? RawResourceAndroidNotificationSound(soundResourceName)
            : null,
        enableVibration: enableVibration,
        showWhen: true,
        when: selectedTime.millisecondsSinceEpoch,
      ),
    );
  }
}
