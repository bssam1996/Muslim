import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/dua_catalog.dart';

class DuaPreferences extends ChangeNotifier {
  DuaPreferences(this.catalog);
  final DuaCatalog catalog;
  final Set<String> favourites = {};
  final List<String> recent = [];
  double fontSize = 28;
  bool transliteration = false;
  bool error = false;
  bool _disposed = false;
  SharedPreferences? _prefs;
  Future<void> _writes = Future.value();
  Future<void> get saved => _writes;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final size = _prefs!.get('duaa.font');
      if (size is num && size.isFinite) {
        fontSize = size.toDouble().clamp(20, 40);
      }
      transliteration = _prefs!.getBool('duaa.transliteration') ?? false;
      for (final id in _prefs!.getStringList('duaa.favourites') ?? <String>[]) {
        final resolved = catalog.resolveId(id);
        if (resolved != null) favourites.add(resolved);
      }
      for (final id in _prefs!.getStringList('duaa.recent') ?? <String>[]) {
        final resolved = catalog.resolveId(id);
        if (resolved != null &&
            !recent.contains(resolved) &&
            recent.length < 20) {
          recent.add(resolved);
        }
      }
    } catch (_) {
      error = true;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _save() {
    final fav = favourites.toList(), history = recent.toList();
    final size = fontSize, show = transliteration;
    _writes = _writes.then((_) async {
      try {
        final prefs = _prefs ??= await SharedPreferences.getInstance();
        final results = await Future.wait([
          prefs.setStringList('duaa.favourites', fav),
          prefs.setStringList('duaa.recent', history),
          prefs.setDouble('duaa.font', size),
          prefs.setBool('duaa.transliteration', show),
        ]);
        error = results.contains(false);
      } catch (_) {
        error = true;
      }
      _notify();
    });
    _notify();
  }

  void toggle(String id) {
    if (catalog.resolveId(id) == null) return;
    if (!favourites.remove(id)) favourites.add(id);
    _save();
  }

  void opened(String id) {
    if (catalog.resolveId(id) == null) return;
    recent.remove(id);
    recent.insert(0, id);
    if (recent.length > 20) recent.removeLast();
    _save();
  }

  void clearRecent() {
    recent.clear();
    _save();
  }

  void resize(double delta) {
    fontSize = (fontSize + delta).clamp(20, 40);
    _save();
  }

  void resetFont() {
    fontSize = 28;
    _save();
  }

  void showTransliteration(bool value) {
    transliteration = value;
    _save();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
