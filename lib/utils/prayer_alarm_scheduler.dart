import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_schedule.dart';
import 'prayer_alarm_lock.dart';

const prayerAlarmManifestKey = 'prayer_alarm_manifest_v2';
const _alarmBase = 1000000;

class PrayerAlarm {
  const PrayerAlarm({
    required this.id,
    required this.name,
    required this.time,
    required this.configuration,
    required this.channelId,
    this.sound,
  });
  final int id;
  final String name;
  final DateTime time;
  final String configuration;
  final String channelId;
  final String? sound;
  String get signature =>
      '$name|${time.millisecondsSinceEpoch}|$configuration|$channelId|$sound';
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'epoch': time.millisecondsSinceEpoch,
    'configuration': configuration,
    'channelId': channelId,
    'sound': sound,
  };
  factory PrayerAlarm.fromJson(Map<String, dynamic> json) => PrayerAlarm(
    id: json['id'] as int,
    name: json['name'] as String,
    time: DateTime.fromMillisecondsSinceEpoch(json['epoch'] as int),
    configuration: json['configuration'] as String,
    channelId: json['channelId'] as String,
    sound: json['sound'] as String?,
  );
}

abstract interface class PrayerAlarmBackend {
  Future<void> schedule(PrayerAlarm alarm);
  Future<void> cancel(int id);
  Future<Set<int>> pendingIds();
}

bool isOwnedPrayerAlarm(int id) =>
    (id >= 0 && id < prayerEvents.length) ||
    (id >= _alarmBase && id < _alarmBase * 3);

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
          enabled[prayerEvents[index]] != true) {
        await backend.cancel(id);
      }
    }
    previous = previous.where((a) => enabled[a.name] == true).toList();
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
    void add(String name, DateTime time) {
      if (name == 'Sunrise' ||
          enabled[name] != true ||
          !time.isAfter(now) ||
          !time.isBefore(prayerDate(now, prayerWindowDays))) {
        return;
      }
      final dayId =
          DateTime.utc(
            time.year,
            time.month,
            time.day,
          ).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
      desired.add(
        PrayerAlarm(
          id:
              _alarmBase * (nextBank + 1) +
              dayId * 10 +
              prayerEvents.indexOf(name),
          name: name,
          time: time,
          configuration: configuration,
          channelId: channels[name]!,
          sound: sounds[name],
        ),
      );
    }

    for (final day in days) {
      for (final entry in day.times.entries) {
        add(entry.key, entry.value);
      }
    }
    // An incomplete refresh must not delete future dates from the same setup.
    for (final old in previous) {
      if (old.configuration == configuration &&
          old.channelId == channels[old.name] &&
          old.sound == sounds[old.name] &&
          !dates.contains(prayerDateKey(old.time))) {
        add(old.name, old.time);
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
    try {
      for (final alarm in desired) {
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
    } catch (_) {
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
