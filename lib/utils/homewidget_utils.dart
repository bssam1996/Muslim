import 'dart:io';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'api_utils.dart' as api_utils;
import 'helper.dart' as helper;

const String dailyRefreshUniqueName = 'daily_prayer_refresh';
const String dailyRefreshTaskName = 'Refresh_Notification_Prayer_Times';
const String frequentWidgetRefreshUniqueName = 'frequent_widget_refresh';
const String frequentWidgetRefreshTaskName = 'Refresh_Widget_Frequent';
const int dailyRefreshAlarmId = 11001;
const int nextPrayerAlarmId = 11002;

const String nextPrayerWidgetDataKey = "next_prayer_key";
const String nextPrayerEpochWidgetDataKey = "next_prayer_epoch_ms";
const String widgetLastCalcEpochWidgetDataKey = "widget_last_calc_epoch_ms";

class NextPrayerState {
  const NextPrayerState({
    required this.prayerKey,
    required this.nextPrayerTime,
    required this.nextChangeTime,
  });

  final String prayerKey;
  final DateTime nextPrayerTime;
  final DateTime nextChangeTime;
}

class _WidgetPrayerSlot {
  const _WidgetPrayerSlot(this.key, this.displayName, this.textStorageKey);

  final String key;
  final String displayName;
  final String textStorageKey;
}

class _ParsedClockTime {
  const _ParsedClockTime(this.hour, this.minute);

  final int hour;
  final int minute;
}

class _PrayerOccurrence {
  const _PrayerOccurrence(this.key, this.dateTime);

  final String key;
  final DateTime dateTime;
}

const List<_WidgetPrayerSlot> _widgetPrayerSlots = <_WidgetPrayerSlot>[
  _WidgetPrayerSlot("fajr", "Fajr", "fajr_text"),
  _WidgetPrayerSlot("sunrise", "Sunrise", "sunrise_text"),
  _WidgetPrayerSlot("dhuhr", "Dhuhr", "dhuhr_text"),
  _WidgetPrayerSlot("asr", "Asr", "asr_text"),
  _WidgetPrayerSlot("maghrib", "Maghrib", "maghrib_text"),
  _WidgetPrayerSlot("isha", "Isha", "isha_text"),
];

DateTime _nextMidnight(DateTime now) {
  final DateTime todayMidnight = DateTime(now.year, now.month, now.day);
  return todayMidnight.add(const Duration(days: 1));
}

String _normalizeNumerals(String input) {
  const Map<String, String> numerals = <String, String>{
    '\u0660': '0',
    '\u0661': '1',
    '\u0662': '2',
    '\u0663': '3',
    '\u0664': '4',
    '\u0665': '5',
    '\u0666': '6',
    '\u0667': '7',
    '\u0668': '8',
    '\u0669': '9',
    '\u06F0': '0',
    '\u06F1': '1',
    '\u06F2': '2',
    '\u06F3': '3',
    '\u06F4': '4',
    '\u06F5': '5',
    '\u06F6': '6',
    '\u06F7': '7',
    '\u06F8': '8',
    '\u06F9': '9',
  };
  String normalized = input;
  numerals.forEach((String source, String target) {
    normalized = normalized.replaceAll(source, target);
  });
  return normalized;
}

_ParsedClockTime? _parseClockTime(String rawValue) {
  if (rawValue.trim().isEmpty || rawValue.trim() == "-") {
    return null;
  }
  final String normalized = _normalizeNumerals(rawValue).toLowerCase();
  final RegExpMatch? match =
      RegExp(r'(\d{1,2})\s*:\s*(\d{2})').firstMatch(normalized);
  if (match == null) {
    return null;
  }

  int? hour = int.tryParse(match.group(1)!);
  int? minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) {
    return null;
  }

  final bool hasAm = RegExp(r'(^|\W)am($|\W)').hasMatch(normalized) ||
      normalized.contains('\u0635');
  final bool hasPm = RegExp(r'(^|\W)pm($|\W)').hasMatch(normalized) ||
      normalized.contains('\u0645');

  if (hasAm || hasPm) {
    hour = hour % 12;
    if (hasPm) {
      hour += 12;
    }
  } else if (hour == 24) {
    hour = 0;
  }

  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return _ParsedClockTime(hour, minute);
}

DateTime _dateTimeAtOffset(
  DateTime today,
  int dayOffset,
  _ParsedClockTime parsed,
) {
  return DateTime(
    today.year,
    today.month,
    today.day + dayOffset,
    parsed.hour,
    parsed.minute,
  );
}

NextPrayerState? computeNextPrayerStateFromTimings(
  Map<String, String> timingsByPrayerKey, {
  DateTime? now,
}) {
  final DateTime currentNow = now ?? DateTime.now();
  final DateTime nowAtMinute = DateTime(
    currentNow.year,
    currentNow.month,
    currentNow.day,
    currentNow.hour,
    currentNow.minute,
  );

  final List<_PrayerOccurrence> occurrences = <_PrayerOccurrence>[];
  for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
    for (final _WidgetPrayerSlot slot in _widgetPrayerSlots) {
      final _ParsedClockTime? parsed =
          _parseClockTime(timingsByPrayerKey[slot.key] ?? "");
      if (parsed == null) {
        continue;
      }
      occurrences.add(
        _PrayerOccurrence(
          slot.key,
          _dateTimeAtOffset(nowAtMinute, dayOffset, parsed),
        ),
      );
    }
  }

  if (occurrences.isEmpty) {
    return null;
  }

  final int selectedIndex =
      occurrences.indexWhere((o) => !o.dateTime.isBefore(nowAtMinute));
  if (selectedIndex < 0) {
    return null;
  }

  final _PrayerOccurrence selectedOccurrence = occurrences[selectedIndex];
  DateTime nextChangeTime;
  if (selectedIndex + 1 < occurrences.length) {
    nextChangeTime = occurrences[selectedIndex + 1].dateTime;
  } else {
    nextChangeTime = selectedOccurrence.dateTime.add(const Duration(days: 1));
  }

  return NextPrayerState(
    prayerKey: selectedOccurrence.key,
    nextPrayerTime: selectedOccurrence.dateTime,
    nextChangeTime: nextChangeTime,
  );
}

Map<String, String> _extractPrayerTimingsByKey(
    Map<String, dynamic> jsonTimings) {
  final Map<String, String> values = <String, String>{};
  for (final _WidgetPrayerSlot slot in _widgetPrayerSlots) {
    values[slot.key] = (jsonTimings[slot.displayName] ?? "").toString();
  }
  return values;
}

Future<Map<String, String>> _readPrayerTimingsFromWidgetData() async {
  final List<Future<String?>> reads = <Future<String?>>[
    for (final _WidgetPrayerSlot slot in _widgetPrayerSlots)
      HomeWidget.getWidgetData<String>(slot.textStorageKey, defaultValue: ""),
  ];
  final List<String?> values = await Future.wait<String?>(reads);
  final Map<String, String> timings = <String, String>{};
  for (int i = 0; i < _widgetPrayerSlots.length; i++) {
    timings[_widgetPrayerSlots[i].key] = values[i] ?? "";
  }
  return timings;
}

Future<void> _saveNextPrayerState(NextPrayerState? state) async {
  await Future.wait<bool?>(<Future<bool?>>[
    HomeWidget.saveWidgetData<String>(
      nextPrayerWidgetDataKey,
      state?.prayerKey ?? "",
    ),
    HomeWidget.saveWidgetData<int>(
      nextPrayerEpochWidgetDataKey,
      state?.nextChangeTime.millisecondsSinceEpoch ?? 0,
    ),
    HomeWidget.saveWidgetData<int>(
      widgetLastCalcEpochWidgetDataKey,
      DateTime.now().millisecondsSinceEpoch,
    ),
  ]);
}

Future<bool> scheduleNextExactMidnightAlarm({String source = "unknown"}) async {
  if (kIsWeb || !Platform.isAndroid) {
    return false;
  }
  final DateTime nextMidnight = _nextMidnight(DateTime.now());
  final bool scheduled = await AndroidAlarmManager.oneShotAt(
    nextMidnight,
    dailyRefreshAlarmId,
    exactMidnightAlarmCallback,
    exact: true,
    allowWhileIdle: true,
    wakeup: true,
    rescheduleOnReboot: true,
  );
  print(
      "[$source] Exact midnight alarm scheduled: $scheduled at $nextMidnight");
  return scheduled;
}

Future<bool> scheduleNextPrayerExactAlarm(
  DateTime requestedTriggerAt, {
  String source = "unknown",
}) async {
  if (kIsWeb || !Platform.isAndroid) {
    return false;
  }

  final DateTime now = DateTime.now();
  DateTime triggerAt = requestedTriggerAt;
  if (!triggerAt.isAfter(now)) {
    final DateTime oneMinuteAhead = now.add(const Duration(minutes: 1));
    triggerAt = DateTime(
      oneMinuteAhead.year,
      oneMinuteAhead.month,
      oneMinuteAhead.day,
      oneMinuteAhead.hour,
      oneMinuteAhead.minute,
    );
  }

  await AndroidAlarmManager.cancel(nextPrayerAlarmId);
  final bool scheduled = await AndroidAlarmManager.oneShotAt(
    triggerAt,
    nextPrayerAlarmId,
    nextPrayerAlarmCallback,
    exact: true,
    allowWhileIdle: true,
    wakeup: true,
    rescheduleOnReboot: true,
  );
  print("[$source] Next prayer alarm scheduled: $scheduled at $triggerAt");
  return scheduled;
}

Future<bool> refreshWidgetOnly({String source = "unknown"}) async {
  try {
    if (!kIsWeb && Platform.isAndroid) {
      await HomeWidget.updateWidget(
        name: "HomeAppWidget",
        androidName: "HomeAppWidget",
      );
      await HomeWidget.updateWidget(
        name: "HomeAppWidgetWide",
        androidName: "HomeAppWidgetWide",
      );
    }
    if (kDebugMode) {
      print("[$source] Widget refresh completed");
    }
    return true;
  } catch (e) {
    print("refreshWidgetOnly failed: $e");
    return false;
  }
}

Future<bool> refreshWidgetHighlightState({String source = "unknown"}) async {
  try {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    final Map<String, String> timingsByPrayerKey =
        await _readPrayerTimingsFromWidgetData();
    final NextPrayerState? nextPrayerState =
        computeNextPrayerStateFromTimings(timingsByPrayerKey);
    if (nextPrayerState == null) {
      if (kDebugMode) {
        print("[$source] No prayer timings available for widget highlight");
      }
      return false;
    }

    await _saveNextPrayerState(nextPrayerState);
    await refreshWidgetOnly(source: "$source:HighlightRefresh");
    await scheduleNextPrayerExactAlarm(
      nextPrayerState.nextChangeTime,
      source: source,
    );
    return true;
  } catch (e) {
    if (kDebugMode) {
      print("refreshWidgetHighlightState failed: $e");
    }
    return false;
  }
}

Future<void> bootstrapWidgetHighlightScheduling({
  String source = "AppStart",
}) async {
  await refreshWidgetHighlightState(source: source);
}

Future<void> updateHomePage(
  Map<String, dynamic> jsonTimings,
  Map<String, dynamic> jsonData,
) async {
  final Map<String, String> timingsByPrayerKey =
      _extractPrayerTimingsByKey(jsonTimings);
  final NextPrayerState? nextPrayerState =
      computeNextPrayerStateFromTimings(timingsByPrayerKey);

  await Future.wait<bool?>([
    HomeWidget.saveWidgetData<String>(
        "fajr_text", jsonTimings["Fajr"].toString()),
    HomeWidget.saveWidgetData<String>("fajr_label", "Fajr".tr()),
    HomeWidget.saveWidgetData<String>(
      "sunrise_text",
      jsonTimings["Sunrise"].toString(),
    ),
    HomeWidget.saveWidgetData<String>("sunrise_label", "Sunrise".tr()),
    HomeWidget.saveWidgetData<String>(
        "dhuhr_text", jsonTimings["Dhuhr"].toString()),
    HomeWidget.saveWidgetData<String>("dhuhr_label", "Dhuhr".tr()),
    HomeWidget.saveWidgetData<String>(
        "asr_text", jsonTimings["Asr"].toString()),
    HomeWidget.saveWidgetData<String>("asr_label", "Asr".tr()),
    HomeWidget.saveWidgetData<String>(
      "maghrib_text",
      jsonTimings["Maghrib"].toString(),
    ),
    HomeWidget.saveWidgetData<String>("maghrib_label", "Maghrib".tr()),
    HomeWidget.saveWidgetData<String>(
        "isha_text", jsonTimings["Isha"].toString()),
    HomeWidget.saveWidgetData<String>("isha_label", "Isha".tr()),
    HomeWidget.saveWidgetData<String>(
      "gregorianDate_text",
      jsonData["gregorian"]?["date"] ?? "Month",
    ),
    HomeWidget.saveWidgetData<String>(
      "hijriDate_text",
      jsonData["hijri"]?["date"] ?? "Month",
    ),
    HomeWidget.saveWidgetData<String>(
      nextPrayerWidgetDataKey,
      nextPrayerState?.prayerKey ?? "",
    ),
    HomeWidget.saveWidgetData<int>(
      nextPrayerEpochWidgetDataKey,
      nextPrayerState?.nextChangeTime.millisecondsSinceEpoch ?? 0,
    ),
    HomeWidget.saveWidgetData<int>(
      widgetLastCalcEpochWidgetDataKey,
      DateTime.now().millisecondsSinceEpoch,
    ),
  ]);

  await refreshWidgetOnly(source: "updateHomePage");
  if (nextPrayerState != null) {
    await scheduleNextPrayerExactAlarm(
      nextPrayerState.nextChangeTime,
      source: "updateHomePage",
    );
  }
}

Future<bool> runDailyRefreshTask({String source = "unknown"}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool shouldFetch = await helper.shouldFetchDailyData(prefs);
  if (!shouldFetch) {
    if (kDebugMode) {
      print("[$source] Daily refresh skipped (already refreshed today)");
    }
    return true;
  }

  final bool refreshed = await refreshPrayerTimesAndReschedule();
  if (refreshed) {
    await helper.updateLastFetchedDate(prefs);
  }
  return refreshed;
}

Future<bool> refreshPrayerTimesAndReschedule() async {
  final Future<SharedPreferences> prefsFuture = SharedPreferences.getInstance();
  try {
    final Map<String, dynamic> savedLocation =
        await api_utils.getSavedLocation();
    if (savedLocation["error"] != "") {
      if (kDebugMode) {
        print("Error getting saved location ${savedLocation["error"]}");
      }
      return false;
    }

    final Map<String, dynamic> dataFromDay =
        await api_utils.getDataFromDay(0, savedLocation);
    if (dataFromDay["error"] != "") {
      if (kDebugMode) {
        print("Error getting date from day ${dataFromDay["error"]}");
      }
      return false;
    }

    dynamic jsonData = dataFromDay["jsonData"];
    jsonData['data']['timings'] =
        await api_utils.getTimings24System(jsonData['data']['timings']);

    if (!kIsWeb && Platform.isAndroid) {
      await updateHomePage(
          jsonData['data']['timings'], jsonData['data']['date']);
      final List<Map<String, dynamic>> jsonTimings = [
        jsonData['data']['timings']
      ];
      await helper.handleNotifications(prefsFuture, jsonTimings);
    }

    return true;
  } catch (e) {
    if (kDebugMode) {
      print("refreshPrayerTimesAndReschedule failed: $e");
    }
    return false;
  }
}

@pragma("vm:entry-point")
void workManagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    if (kDebugMode) {
      print("Workmanager task $task");
      print("Workmanager inputData $inputData");
    }
    if (task == frequentWidgetRefreshTaskName) {
      final bool dailyCheckResult = await runDailyRefreshTask(
        source: "WorkManager:$task:DailyCheck",
      );
      final bool highlighted = await refreshWidgetHighlightState(
        source: "WorkManager:$task",
      );
      if (highlighted) {
        return dailyCheckResult || highlighted;
      }
      final bool refreshed =
          await refreshWidgetOnly(source: "WorkManager:$task");
      return dailyCheckResult || refreshed;
    }
    return runDailyRefreshTask(source: "WorkManager:$task");
  });
}

@pragma("vm:entry-point")
Future<void> exactMidnightAlarmCallback() async {
  DartPluginRegistrant.ensureInitialized();
  await runDailyRefreshTask(source: "AlarmManager");
  await refreshWidgetHighlightState(source: "AlarmManager:Midnight");
  await scheduleNextExactMidnightAlarm(source: "AlarmManager");
}

@pragma("vm:entry-point")
Future<void> nextPrayerAlarmCallback() async {
  DartPluginRegistrant.ensureInitialized();
  await refreshWidgetHighlightState(source: "AlarmManager:NextPrayer");
}
