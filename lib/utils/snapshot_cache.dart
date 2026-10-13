import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'serial_task_queue.dart';

class CachedSnapshot {
  const CachedSnapshot(this.payload, this.savedAt);
  final String payload;
  final DateTime savedAt;
}

/// Small, bounded caches. Identity includes the feature's relevant settings.
class SnapshotCache {
  const SnapshotCache(this.preferences, this.prefix, {this.limit = 6});
  final SharedPreferences preferences;
  final String prefix;
  final int limit;
  static final _writes = SerialTaskQueue();

  CachedSnapshot? read(String identity) {
    try {
      final raw = preferences.getString('$prefix$identity');
      if (raw == null) return null;
      final value = jsonDecode(raw) as Map;
      return CachedSnapshot(
        value['payload'] as String,
        DateTime.parse(value['savedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  CachedSnapshot? latest() {
    final values =
        preferences
            .getKeys()
            .where((key) => key.startsWith(prefix))
            .map((key) => read(key.substring(prefix.length)))
            .whereType<CachedSnapshot>()
            .toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return values.isEmpty ? null : values.first;
  }

  Future<void> write(
    String identity,
    String payload, {
    DateTime? now,
  }) => _writes.run(() async {
    if (!await preferences.setString(
      '$prefix$identity',
      jsonEncode({
        'savedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
        'payload': payload,
      }),
    )) {
      throw StateError('Cache write failed');
    }
    final keys =
        preferences.getKeys().where((key) => key.startsWith(prefix)).toList()
          ..sort(
            (a, b) =>
                (read(b.substring(prefix.length))?.savedAt ?? DateTime(1970))
                    .compareTo(
                      read(a.substring(prefix.length))?.savedAt ??
                          DateTime(1970),
                    ),
          );
    for (final key in keys.skip(limit)) {
      await preferences.remove(key);
    }
  });
}
