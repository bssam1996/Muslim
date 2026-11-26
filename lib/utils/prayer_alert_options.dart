import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

String prayerAlertOptionsKey(String name) => 'prayerNotificationOptions$name';

const reminderMinutePresets = [5, 10, 15, 20, 30, 45, 60];
const reminderPrepareText = 'Prayer_Reminder_Prepare_Text';
const reminderPreviousText = 'Prayer_Reminder_Previous_Text';

/// Optional settings preserve the behavior of existing installations.
class PrayerAlertOptions {
  const PrayerAlertOptions({
    this.forceSound = false,
    this.volume,
    this.reminderEnabled = false,
    this.reminderMinutes = 10,
    this.reminderText = reminderPrepareText,
    this.reminderSound = 'system',
  });

  final bool forceSound;
  final double? volume;
  final bool reminderEnabled;
  final int reminderMinutes;
  final String reminderText;

  /// `system`, `silent`, or an Android raw resource name.
  final String reminderSound;

  Map<String, dynamic> toJson() => {
    'forceSound': forceSound,
    'volume': volume,
    'reminderEnabled': reminderEnabled,
    'reminderMinutes': reminderMinutes,
    'reminderText': reminderText,
    'reminderSound': reminderSound,
  };

  factory PrayerAlertOptions.fromJson(Map<String, dynamic> json) {
    final minutes = json['reminderMinutes'];
    final volume = json['volume'];
    return PrayerAlertOptions(
      forceSound: json['forceSound'] == true,
      volume: volume is num && volume.isFinite
          ? volume.toDouble().clamp(0.0, 1.0)
          : null,
      reminderEnabled: json['reminderEnabled'] == true,
      reminderMinutes: minutes is int ? minutes.clamp(1, 180) : 10,
      reminderText:
          json['reminderText'] is String &&
              (json['reminderText'] as String).trim().isNotEmpty
          ? (json['reminderText'] as String).trim()
          : reminderPrepareText,
      reminderSound: json['reminderSound'] is String
          ? json['reminderSound'] as String
          : 'system',
    );
  }

  static PrayerAlertOptions read(SharedPreferences prefs, String name) {
    try {
      return PrayerAlertOptions.fromJson(
        jsonDecode(prefs.getString(prayerAlertOptionsKey(name)) ?? '{}')
            as Map<String, dynamic>,
      );
    } catch (_) {
      return const PrayerAlertOptions();
    }
  }
}
