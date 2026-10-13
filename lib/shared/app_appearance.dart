import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAppearance extends ChangeNotifier {
  AppAppearance(this.preferences)
    : _mode = ThemeMode.values.firstWhere(
        (value) => value.name == preferences.getString('app_theme_mode'),
        orElse: () => ThemeMode.system,
      );
  final SharedPreferences preferences;
  ThemeMode _mode;
  ThemeMode get mode => _mode;

  Future<bool> setMode(ThemeMode value) async {
    if (value == _mode) return true;
    if (!await preferences.setString('app_theme_mode', value.name)) {
      return false;
    }
    _mode = value;
    notifyListeners();
    return true;
  }
}

class AppAppearanceScope extends InheritedNotifier<AppAppearance> {
  const AppAppearanceScope({
    super.key,
    required AppAppearance appearance,
    required super.child,
  }) : super(notifier: appearance);

  static AppAppearance? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppAppearanceScope>()
      ?.notifier;
}
