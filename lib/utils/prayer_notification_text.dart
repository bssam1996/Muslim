import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_alert_options.dart';

/// Notification scheduling also runs in headless Flutter engines. Those engines
/// have an asset bundle, but no EasyLocalization widget or loaded UI catalogue.
class PrayerNotificationText {
  PrayerNotificationText._(this.locale, this._messages);

  final String locale;
  final Map<String, dynamic> _messages;
  static final _loaded = <String, PrayerNotificationText>{};

  static String localeFor(SharedPreferences prefs) {
    final language =
        (prefs.getString('locale') ??
                ServicesBinding.instance.platformDispatcher.locale.toString())
            .replaceAll('_', '-')
            .split('-')
            .first
            .toLowerCase();
    return language == 'ar' ? 'ar-EG' : 'en-US';
  }

  static PrayerNotificationText? cached(SharedPreferences prefs) =>
      _loaded[localeFor(prefs)];

  static Future<PrayerNotificationText> load(
    SharedPreferences prefs, {
    String? locale,
  }) async {
    final selected = locale ?? localeFor(prefs);
    final cached = _loaded[selected];
    if (cached != null) return cached;
    Future<Map<String, dynamic>> catalogue(String locale) async =>
        jsonDecode(
              await rootBundle.loadString('assets/translations/$locale.json'),
            )
            as Map<String, dynamic>;
    final messages = await catalogue('en-US');
    if (selected != 'en-US') messages.addAll(await catalogue(selected));
    return _loaded[selected] = PrayerNotificationText._(selected, messages);
  }

  String text(String key, [Map<String, String> arguments = const {}]) {
    final message = _messages[key];
    if (message is! String || message.isEmpty) {
      throw StateError(
        'Missing prayer notification translation: $key ($locale)',
      );
    }
    return arguments.entries.fold<String>(
      message,
      (text, entry) => text.replaceAll('{${entry.key}}', entry.value),
    );
  }

  String title(String prayer, {bool reminder = false}) => reminder
      ? text('Prayer_Reminder_Title', {'prayer': text(prayer)})
      : text(prayer);

  String prayerBody(String prayer) =>
      "${text("Don't forget praying")} ${text(prayer)}";

  String reminderBody(String prayer, PrayerAlertOptions options) =>
      [reminderPrepareText, reminderPreviousText].contains(options.reminderText)
      ? text(options.reminderText, {
          'prayer': text(prayer),
          'minutes': options.reminderMinutes.toString(),
        })
      : options.reminderText;
}
