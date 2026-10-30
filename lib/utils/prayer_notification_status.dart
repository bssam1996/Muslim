import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/constants.dart';
import 'helper.dart' as helper;
import 'notification_service.dart';
import 'prayer_alarm_scheduler.dart';
import 'prayer_schedule.dart';
import 'prayer_alert_options.dart';

class PrayerNotificationStatus {
  const PrayerNotificationStatus({
    this.supported = true,
    this.notifications,
    this.exactAlarms,
    this.nextAlarm,
    this.use24Hour = true,
  });
  final bool supported;
  final bool? notifications;
  final bool? exactAlarms;
  final PrayerAlarm? nextAlarm;
  final bool use24Hour;
}

/// Only announces future, enabled, current-configuration alarms still in the OS.
Future<PrayerNotificationStatus> readPrayerNotificationStatus() async {
  if (kIsWeb || !Platform.isAndroid) {
    return const PrayerNotificationStatus(supported: false);
  }
  final service = NotificationService();
  final (notifications, exact) = await service.readPermissions();
  final pending = await service.pendingIds();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final location =
      jsonDecode(prefs.getString('location') ?? '{}') as Map<String, dynamic>;
  final path = await helper.constructAPIParameters(
    '',
    helper.dateFormatter(DateTime.now()),
    location,
    Future.value(prefs),
  );
  final next = confirmedPrayerAlarms(
    prefs,
    pending,
    configuration: path == null ? '' : prayerConfigurationIdentity(path),
  );
  return PrayerNotificationStatus(
    notifications: notifications,
    exactAlarms: exact,
    nextAlarm: next.firstOrNull,
    use24Hour: prefs.getBool('24system') ?? true,
  );
}

List<PrayerAlarm> confirmedPrayerAlarms(
  SharedPreferences prefs,
  Set<int> pending, {
  required String configuration,
  DateTime? now,
}) {
  if (prefs.getBool('prayerNotification') != true || configuration.isEmpty) {
    return [];
  }
  try {
    final manifest =
        jsonDecode(prefs.getString(prayerAlarmManifestKey) ?? '{}') as Map;
    return (manifest['alarms'] as List? ?? [])
        .map(
          (raw) => PrayerAlarm.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .where((alarm) {
          final name = alarm.name;
          final mode =
              prefs.getString(prayerNotificationModePreferenceKey(name)) ??
              prayerNotificationModeVibrationOnly;
          final sound =
              prefs.getString(prayerNotificationSoundPreferenceKey(name)) ?? '';
          final resource =
              mode == prayerNotificationModeCustomSound && sound.isNotEmpty
              ? androidRawResourceNameFromSoundKey(sound)
              : null;
          final options = PrayerAlertOptions.read(prefs, name);
          final matchesAlert = alarm.isReminder
              ? options.reminderEnabled &&
                    alarm.forceSound ==
                        (options.reminderSound != 'silent' &&
                            options.forceSound) &&
                    alarm.volume ==
                        (options.reminderSound != 'silent'
                            ? options.volume
                            : null) &&
                    alarm.channelId ==
                        'muslim_reminder_${name.toLowerCase()}_${options.reminderSound}_v1' &&
                    alarm.occurrenceTime.difference(alarm.time).inMinutes ==
                        options.reminderMinutes &&
                    alarm.body ==
                        ([
                              reminderPrepareText,
                              reminderPreviousText,
                            ].contains(options.reminderText)
                            ? options.reminderText.tr(
                                namedArgs: {
                                  'prayer': name.tr(),
                                  'minutes': '${options.reminderMinutes}',
                                },
                              )
                            : options.reminderText)
              : alarm.channelId ==
                        prayerNotificationAndroidChannelId(
                          name,
                          mode,
                          resource,
                        ) &&
                    alarm.forceSound ==
                        (resource != null && options.forceSound) &&
                    alarm.volume == (resource != null ? options.volume : null);
          return PRAYER_NOTIFICATION_NAMES.contains(name) &&
              isOwnedPrayerAlarm(alarm.id) &&
              pending.contains(alarm.id) &&
              alarm.time.isAfter(now ?? DateTime.now()) &&
              alarm.configuration == configuration &&
              (prefs.getBool(prayerNotificationPreferenceKey(name)) ?? true) &&
              matchesAlert;
        })
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  } catch (_) {
    return [];
  }
}
