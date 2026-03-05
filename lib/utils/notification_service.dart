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
  Future<void> clearAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
  Future<void> init() async {
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
  }

  Future<String> scheduleDailyNotification(DateTime selectedTime, int zoneId, String channelId, String title, String body) async {
    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(selectedTime, tz.local);
    tz.TZDateTime.local(selectedTime.year, selectedTime.month, selectedTime.day, selectedTime.hour, selectedTime.minute, selectedTime.second);

    try {
      await _notificationsPlugin.zonedSchedule(
        id: zoneId,
        title: title,
        body: body,
        scheduledDate: scheduledTime,
        notificationDetails: _notificationDetails(channelId, title, body, selectedTime),
        matchDateTimeComponents: DateTimeComponents.time, androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
      print('Notification scheduled successfully');
      return "";
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