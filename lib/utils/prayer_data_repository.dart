import 'api_utils.dart' as api;
import 'helper.dart' as helper;
import 'prayer_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'homewidget_utils.dart' as widgets;
import 'refresh_coordinator.dart';
import 'web_push_service.dart';

final _settingsRefresh = RefreshCoordinator();

/// Calculation and display changes use the same dated window for widgets and
/// prayer notifications. Concurrent changes coalesce after the current load.
Future<bool> refreshSavedPrayerConfiguration() =>
    _settingsRefresh.runAfterCurrent(() async {
      final webPushSynced = kIsWeb ? await syncSavedWebPush() : true;
      final window = await loadSavedPrayerWindow();
      if (window.configuration.isEmpty) return false;
      final success = await helper.handleNotifications(
        SharedPreferences.getInstance(),
        window.days,
        configuration: window.configuration,
      );
      if (!kIsWeb && Platform.isAndroid && window.days.isNotEmpty) {
        await widgets.updateHomePage(window.days, window.configuration);
      }
      return success && window.complete && webPushSynced;
    });

class SavedPrayerWindow {
  const SavedPrayerWindow(
    this.date,
    this.configuration,
    this.days,
    this.complete,
  );
  final DateTime date;
  final String configuration;
  final List<PrayerDay> days;
  final bool complete;
}

Future<SavedPrayerWindow> loadSavedPrayerWindow({
  bool cacheOnly = false,
  DateTime? baseDate,
}) async {
  final date = prayerDate(baseDate ?? DateTime.now());
  final prefs = SharedPreferences.getInstance();
  final location = await api.getSavedLocation();
  if (location['error'] != '') return SavedPrayerWindow(date, '', [], false);
  final path = await helper.constructAPIParameters(
    '',
    helper.dateFormatter(date),
    location,
    prefs,
  );
  if (path == null) return SavedPrayerWindow(date, '', [], false);
  final loaded = <int, PrayerDay>{};
  final missing = <int>[];
  PrayerDay parse(int offset, Map<String, dynamic> result) {
    final data = result['jsonData']['data'] as Map;
    return PrayerDay(
      prayerDate(date, offset),
      Map<String, dynamic>.from(data['timings'] as Map),
      dateData: Map<String, dynamic>.from(data['date'] as Map),
    );
  }

  for (var offset = 0; offset < prayerWindowDays; offset++) {
    final result = await api.getDataFromDay(
      offset,
      location,
      cacheOnly: true,
      baseDate: date,
    );
    if (result['error'] == '') {
      loaded[offset] = parse(offset, result);
    } else {
      missing.add(offset);
    }
  }
  if (!cacheOnly) {
    for (final offset in missing) {
      final result = await api.getDataFromDay(offset, location, baseDate: date);
      if (result['error'] != '') break;
      loaded[offset] = parse(offset, result);
    }
  }
  await (await prefs).reload();
  final currentPath = await helper.constructAPIParameters(
    '',
    helper.dateFormatter(date),
    await api.getSavedLocation(),
    prefs,
  );
  // Do not publish a response assembled while the user changed calculation settings.
  if (path != currentPath) return SavedPrayerWindow(date, '', [], false);
  final days = loaded.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  return SavedPrayerWindow(
    date,
    prayerConfigurationIdentity(path),
    days,
    days.length == prayerWindowDays,
  );
}

Future<bool> reconcileSavedPrayerNotifications() async {
  final prefs = SharedPreferences.getInstance();
  // Disabling is immediate even if location or network data cannot be loaded.
  await helper.handleNotifications(prefs, []);
  if ((await prefs).getBool('prayerNotification') != true) return true;
  final window = await loadSavedPrayerWindow();
  final success = await helper.handleNotifications(
    prefs,
    window.days,
    configuration: window.configuration,
  );
  return success && window.complete;
}
