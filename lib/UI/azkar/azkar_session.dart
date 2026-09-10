import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'azkar_items.dart';

/// Explicit sessions, not daily streaks: nothing resets at midnight.
/// Counts are keyed by exact content and target, so reordering cannot attach
/// progress to a different dhikr after a content update.
class AzkarSession extends ChangeNotifier {
  AzkarSession(this.category, this.items);
  final String category;
  final List<AzkarItem> items;
  static const minFontSize = 20.0;
  static const maxFontSize = 40.0;
  static const fontKey = 'azkar.fontSize';
  String get storageKey => 'azkar.session.v1.$category';
  double fontSize = 28;
  int index = 0;
  bool loaded = false;
  bool storageError = false;
  bool _disposed = false;
  SharedPreferences? _prefs;
  final Map<String, int> _counts = {};
  Future<void> _writes = Future.value();
  Future<void> get saved => _writes;
  String _id(int i) => '${items[i].count}:${items[i].data}';
  int countAt(int i) => _counts[_id(i)] ?? 0;
  int get completed => [
    for (var i = 0; i < items.length; i++) i,
  ].where((i) => countAt(i) >= items[i].count).length;
  int get repetitions => _counts.values.fold(0, (a, b) => a + b);
  bool get finished => items.isNotEmpty && completed == items.length;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final size = _prefs!.get(fontKey);
      if (size is num && size.isFinite) {
        fontSize = size.toDouble().clamp(minFontSize, maxFontSize);
      }
      final raw = _prefs!.getString(storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['counts'] is Map) {
          final counts = decoded['counts'] as Map;
          for (var i = 0; i < items.length; i++) {
            final value = counts[_id(i)];
            if (value is int) _counts[_id(i)] = value.clamp(0, items[i].count);
            if (decoded['current'] == _id(i)) index = i;
          }
        }
      }
    } catch (_) {
      storageError = true;
    }
    loaded = true;
    _notify();
  }

  void _save({bool saveFont = false}) {
    final snapshot = jsonEncode({
      'current': items.isEmpty ? null : _id(index),
      'counts': _counts,
    });
    final size = fontSize;
    // Serialize writes so rapid taps cannot leave an older count on disk.
    _writes = _writes.then((_) async {
      try {
        final prefs = _prefs ??= await SharedPreferences.getInstance();
        final sessionOk = await prefs.setString(storageKey, snapshot);
        final fontOk = !saveFont || await prefs.setDouble(fontKey, size);
        if (!sessionOk || !fontOk) throw StateError('Preferences not saved');
        storageError = false;
      } catch (_) {
        storageError = true;
      }
      _notify();
    });
    _notify();
  }

  void changeCount(int delta) {
    if (!loaded || items.isEmpty) return;
    _counts[_id(index)] = (countAt(index) + delta).clamp(0, items[index].count);
    _save();
  }

  void select(int value) {
    if (!loaded || value < 0 || value >= items.length) return;
    index = value;
    _save();
  }

  void resize(double delta) {
    if (!loaded) return;
    fontSize = (fontSize + delta).clamp(minFontSize, maxFontSize);
    _save(saveFont: true);
  }

  void reset() {
    if (!loaded) return;
    _counts.clear();
    index = 0;
    _save();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
