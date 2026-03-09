import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void> clearAllNotifications() async {
    await _notificationsPlugin.cancelAll();
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

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );
    _initialized = true;
  }

  Future<bool> requestExactAlarmPermissionIfNeeded() async {
    await init();
    if (!Platform.isAndroid) {
      return true;
    }
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
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

  Future<AndroidScheduleMode> _preferredAndroidScheduleMode() async {
    if (!Platform.isAndroid) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    final bool canScheduleExact =
        await androidPlugin.canScheduleExactNotifications() ?? false;
    return canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<String> scheduleDailyNotification(DateTime selectedTime, int zoneId, String channelId, String title, String body) async {
    await init();
    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(selectedTime, tz.local);
    tz.TZDateTime.local(selectedTime.year, selectedTime.month, selectedTime.day, selectedTime.hour, selectedTime.minute, selectedTime.second);

    final AndroidScheduleMode preferredMode =
        await _preferredAndroidScheduleMode();

    try {
      await _notificationsPlugin.zonedSchedule(
        id: zoneId,
        title: title,
        body: body,
        scheduledDate: scheduledTime,
        notificationDetails: _notificationDetails(channelId, title, body, selectedTime),
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: preferredMode,
      );
      print('Notification scheduled successfully');
      return "";
    } on PlatformException catch (e) {
      if (e.code == "exact_alarms_not_permitted" &&
          (preferredMode == AndroidScheduleMode.alarmClock ||
              preferredMode == AndroidScheduleMode.exact ||
              preferredMode == AndroidScheduleMode.exactAllowWhileIdle)) {
        if (kDebugMode) {
          print("Exact alarms unavailable. Falling back to inexact schedule.");
        }
        await _notificationsPlugin.zonedSchedule(
          id: zoneId,
          title: title,
          body: body,
          scheduledDate: scheduledTime,
          notificationDetails:
              _notificationDetails(channelId, title, body, selectedTime),
          matchDateTimeComponents: DateTimeComponents.time,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        return "";
      }
      print('Error scheduling notification: $e');
      return 'Error scheduling notification: $e';
    } catch (e) {
      print('Error scheduling notification: $e');
      return 'Error scheduling notification: $e';
    }
  }

  NotificationDetails _notificationDetails(String id, String title, String body, DateTime selectedTime) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        title,
        channelDescription: body,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        when: selectedTime.millisecondsSinceEpoch,
      ),
    );
  }

}
