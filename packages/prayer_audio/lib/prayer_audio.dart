import 'package:flutter/services.dart';

/// Registered in foreground and background Flutter engines.
class PrayerAudio {
  static const _channel = MethodChannel('com.bplusplus.muslim/prayer_audio');

  static Future<void> schedule(Map<String, dynamic> alarm) =>
      _channel.invokeMethod<void>('schedule', alarm);

  static Future<void> cancel(int id) =>
      _channel.invokeMethod<void>('cancel', {'id': id});

  static Future<Set<int>> pendingIds() async =>
      (await _channel.invokeListMethod<int>('pendingIds') ?? []).toSet();

  static Future<void> stop() => _channel.invokeMethod<void>('stop');
}
