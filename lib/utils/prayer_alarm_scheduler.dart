import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_schedule.dart';
import 'prayer_alert_options.dart';
import 'prayer_alarm_lock.dart';

const prayerAlarmManifestKey = 'prayer_alarm_manifest_v2';
const _alarmBase = 1000000;
const prayerAudioDeliveryVersion = 2;

class PrayerAlarm {
  const PrayerAlarm({
    required this.id,
    required this.name,
    required this.time,
    required this.configuration,
    required this.channelId,
    this.sound,
    this.forceSound = false,
    this.volume,
    this.isReminder = false,
    this.body,
    this.prayerTime,
    this.deliveryVersion = prayerAudioDeliveryVersion,
  });
  final int id;
  final String name;
  final DateTime time;
  final String configuration;
  final String channelId;
  final String? sound;
  final bool forceSound;
  final double? volume;
  final bool isReminder;
  final String? body;
  final DateTime? prayerTime;
  final int deliveryVersion;
  DateTime get occurrenceTime => prayerTime ?? time;
  String get signature =>
      '$name|${time.millisecondsSinceEpoch}|$configuration|$channelId|$sound|$forceSound|$volume|$isReminder|$body|$deliveryVersion';
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'epoch': time.millisecondsSinceEpoch,
    'configuration': configuration,
    'channelId': channelId,
    'sound': sound,
    'forceSound': forceSound,
    'volume': volume,
    'isReminder': isReminder,
    'body': body,
    'prayerEpoch': prayerTime?.millisecondsSinceEpoch,
    'deliveryVersion': deliveryVersion,
  };
  factory PrayerAlarm.fromJson(Map<String, dynamic> json) => PrayerAlarm(
    id: json['id'] as int,
    name: json['name'] as String,
    time: DateTime.fromMillisecondsSinceEpoch(json['epoch'] as int),
    configuration: json['configuration'] as String,
    channelId: json['channelId'] as String,
    sound: json['sound'] as String?,
    forceSound: json['forceSound'] == true,
    volume: (json['volume'] as num?)?.toDouble(),
    isReminder: json['isReminder'] == true,
    body: json['body'] as String?,
    deliveryVersion: json['deliveryVersion'] as int? ?? 1,
    prayerTime: json['prayerEpoch'] is int
        ? DateTime.fromMillisecondsSinceEpoch(json['prayerEpoch'] as int)
        : null,
  );
}

abstract interface class PrayerAlarmBackend {
  Future<void> schedule(PrayerAlarm alarm);
  Future<void> cancel(int id);
  Future<Set<int>> pendingIds();
}

bool isOwnedPrayerAlarm(int id) =>
    (id >= 0 && id < prayerEvents.length) ||
    (id >= _alarmBase && id < _alarmBase * 3) ||
    (id >= 11000000 && id < 13000000);

/// Stages replacements in a different ID bank before committing the manifest.
/// Failed staging leaves the previously committed alarms intact.
class PrayerAlarmReconciler {
  PrayerAlarmReconciler(this.preferences, this.backend);
  final SharedPreferences preferences;
  final PrayerAlarmBackend backend;
  static Future<void> _queue = Future.value();

  Future<bool> reconcile({
    required List<PrayerDay> days,
    required String configuration,
    required Map<String, bool> enabled,
    required Map<String, String> channels,
    required Map<String, String?> sounds,
    required DateTime now,
    Map<String, PrayerAlertOptions> options = const {},
    Map<String, String> reminderBodies = const {},
    Future<bool> Function()? stillCurrent,
  }) {
    final result = Completer<bool>();
    _queue = _queue.then((_) async {
      try {
        result.complete(
          await withPrayerAlarmLock(
            () => _reconcile(
              days: days,
              configuration: configuration,
              enabled: enabled,
              channels: channels,
              sounds: sounds,
              now: now,
              options: options,
              reminderBodies: reminderBodies,
              stillCurrent: stillCurrent,
            ),
          ),
        );
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<bool> _reconcile({
    required List<PrayerDay> days,
    required String configuration,
    required Map<String, bool> enabled,
    required Map<String, String> channels,
    required Map<String, String?> sounds,
    required DateTime now,
    Map<String, PrayerAlertOptions> options = const {},
    Map<String, String> reminderBodies = const {},
    Future<bool> Function()? stillCurrent,
  }) async {
    await preferences.reload();
    if (stillCurrent != null && !await stillCurrent()) return false;
    var bank = 0;
    var previous = <PrayerAlarm>[];
    try {
      final json =
          jsonDecode(preferences.getString(prayerAlarmManifestKey) ?? '{}')
              as Map;
      bank = json['bank'] as int? ?? 0;
      previous = (json['alarms'] as List? ?? [])
          .map((e) => PrayerAlarm.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // Pending IDs still allow disabled or orphaned alarms to be removed.
    }
    final pending = await backend.pendingIds();
    // Explicitly disabling a prayer takes effect even with no usable data.
    for (final id in pending.where(isOwnedPrayerAlarm)) {
      final index = id < _alarmBase ? id : id % 10;
      if (index >= prayerEvents.length ||
          enabled[prayerEvents[index]] != true ||
          (id >= 11000000 &&
              options[prayerEvents[index]]?.reminderEnabled != true)) {
        await backend.cancel(id);
      }
    }
    previous = previous
        .where(
          (a) =>
              enabled[a.name] == true &&
              (!a.isReminder || options[a.name]?.reminderEnabled == true),
        )
        .toList();
    if (!enabled.values.any((v) => v)) {
      return preferences.setString(
        prayerAlarmManifestKey,
        jsonEncode({'bank': bank, 'alarms': []}),
      );
    }
    if (days.isEmpty || configuration.isEmpty) return false;
    final dates = days.map((d) => prayerDateKey(d.date)).toSet();
    final nextBank = bank == 0 ? 1 : 0;
    final desired = <PrayerAlarm>[];
    void add(String name, DateTime prayerTime) {
      if (name == 'Sunrise' ||
          enabled[name] != true ||
          !prayerTime.isBefore(prayerDate(now, prayerWindowDays))) {
        return;
      }
      final settings = options[name] ?? const PrayerAlertOptions();
      final dayId =
          DateTime.utc(
            prayerTime.year,
            prayerTime.month,
            prayerTime.day,
          ).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
      final id =
          _alarmBase * (nextBank + 1) + dayId * 10 + prayerEvents.indexOf(name);
      if (prayerTime.isAfter(now)) {
        desired.add(
          PrayerAlarm(
            id: id,
            name: name,
            time: prayerTime,
            configuration: configuration,
            channelId: channels[name]!,
            sound: sounds[name],
            forceSound: sounds[name] != null && settings.forceSound,
            volume: sounds[name] != null ? settings.volume : null,
          ),
        );
      }
      final reminderTime = prayerTime.subtract(
        Duration(minutes: settings.reminderMinutes),
      );
      if (settings.reminderEnabled && reminderTime.isAfter(now)) {
        desired.add(
          PrayerAlarm(
            id: id + 10000000,
            name: name,
            time: reminderTime,
            configuration: configuration,
            channelId:
                'muslim_reminder_${name.toLowerCase()}_${settings.reminderSound}_v1',
            sound: settings.reminderSound == 'silent'
                ? null
                : settings.reminderSound,
            forceSound:
                settings.reminderSound != 'silent' && settings.forceSound,
            volume: settings.reminderSound != 'silent' ? settings.volume : null,
            isReminder: true,
            prayerTime: prayerTime,
            body: reminderBodies[name] ?? settings.reminderText,
          ),
        );
      }
    }

    for (final day in days) {
      for (final entry in day.times.entries) {
        add(entry.key, entry.value);
      }
    }
    // Rebuild absent cached dates with current alert settings, retaining the
    // actual prayer instant even when its reminder falls on the previous date.
    final retained = <String>{};
    for (final old in previous) {
      if (old.configuration == configuration &&
          !dates.contains(prayerDateKey(old.occurrenceTime)) &&
          retained.add(
            '${old.name}|${old.occurrenceTime.millisecondsSinceEpoch}',
          )) {
        add(old.name, old.occurrenceTime);
      }
    }
    final oldSignatures = previous
        .where((a) => a.time.isAfter(now))
        .map((a) => a.signature)
        .toSet();
    final newSignatures = desired.map((a) => a.signature).toSet();
    final unchanged =
        oldSignatures.length == newSignatures.length &&
        oldSignatures.containsAll(newSignatures) &&
        previous
            .where((a) => a.time.isAfter(now))
            .every((a) => pending.contains(a.id));
    if (unchanged) {
      final keep = previous
          .where((a) => a.time.isAfter(now))
          .map((a) => a.id)
          .toSet();
      for (final id
          in pending
              .where(isOwnedPrayerAlarm)
              .where((id) => !keep.contains(id))) {
        await backend.cancel(id);
      }
      return true;
    }
    final staged = <int>[];
    PrayerAlarm? stagingAlarm;
    try {
      for (final alarm in desired) {
        stagingAlarm = alarm;
        staged.add(alarm.id);
        await backend.schedule(alarm);
      }
      if (stillCurrent != null && !await stillCurrent()) {
        throw StateError('Prayer settings changed during alarm staging');
      }
      if (!await preferences.setString(
        prayerAlarmManifestKey,
        jsonEncode({
          'bank': nextBank,
          'alarms': desired.map((a) => a.toJson()).toList(),
        }),
      )) {
        throw StateError('Could not save prayer alarm manifest');
      }
    } catch (error, stack) {
      debugPrint(
        'Prayer alarm staging failed '
        '(prayer: ${stagingAlarm?.name}, reminder: ${stagingAlarm?.isReminder}, '
        'sound: ${stagingAlarm?.sound}): $error\n$stack',
      );
      for (final id in staged) {
        await backend.cancel(id);
      }
      return false;
    }
    final keep = desired.map((a) => a.id).toSet();
    for (final id
        in pending
            .where(isOwnedPrayerAlarm)
            .where((id) => !keep.contains(id))) {
      await backend.cancel(id);
    }
    return true;
  }
}
