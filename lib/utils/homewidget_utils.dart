import 'dart:convert';
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
import 'prayer_schedule.dart';
import 'prayer_data_repository.dart';

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

const List<_WidgetPrayerSlot> _widgetPrayerSlots = <_WidgetPrayerSlot>[
  _WidgetPrayerSlot("fajr", "Fajr", "fajr_text"),
  _WidgetPrayerSlot("sunrise", "Sunrise", "sunrise_text"),
  _WidgetPrayerSlot("dhuhr", "Dhuhr", "dhuhr_text"),
  _WidgetPrayerSlot("asr", "Asr", "asr_text"),
  _WidgetPrayerSlot("maghrib", "Maghrib", "maghrib_text"),
  _WidgetPrayerSlot("isha", "Isha", "isha_text"),
];

const widgetPrayerSnapshotKey = 'prayer_snapshot_v2';

PrayerDay? widgetPrayerDisplayDay(List<PrayerDay> days, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = days
      .where((day) => day.date == prayerDate(current))
      .firstOrNull;
  if (today == null) return null;
  final next = nextPrayerOccurrence(days, current);
  return next == null
      ? today
      : days.where((day) => day.date == prayerDate(next.time)).firstOrNull;
}

DateTime _nextMidnight(DateTime now) => prayerDate(now, 1);

NextPrayerState? computeNextPrayerState(List<PrayerDay> days, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final next = nextPrayerOccurrence(days, current);
  if (next == null) return null;
  final transition = next.time.add(const Duration(seconds: 1));
  final midnight = _nextMidnight(current);
  return NextPrayerState(
    prayerKey: next.name.toLowerCase(),
    nextPrayerTime: next.time,
    nextChangeTime: midnight.isBefore(transition) ? midnight : transition,
  );
}

// Compatibility entry point; tomorrow must be supplied rather than inferred.
NextPrayerState? computeNextPrayerStateFromTimings(
  Map<String, String> timings, {
  DateTime? now,
  Map<String, String>? tomorrowTimings,
}) {
  final current = now ?? DateTime.now();
  try {
    Map<String, dynamic> named(Map<String, String> values) => {
      for (final name in prayerEvents) name: values[name.toLowerCase()],
    };
    return computeNextPrayerState([
      PrayerDay(current, named(timings)),
      if (tomorrowTimings != null)
        PrayerDay(prayerDate(current, 1), named(tomorrowTimings)),
    ], now: current);
  } on FormatException {
    return null;
  }
}

Future<List<PrayerDay>> _readWidgetPrayerDays() async {
  try {
    final raw = await HomeWidget.getWidgetData<String>(widgetPrayerSnapshotKey);
    if (raw == null) return [];
    final json = jsonDecode(raw) as Map;
    final location = await api_utils.getSavedLocation();
    if (location['error'] != '') return [];
    final path = await helper.constructAPIParameters(
      '',
      helper.dateFormatter(DateTime.now()),
      location,
      SharedPreferences.getInstance(),
    );
    if (path == null ||
        json['configuration'] != prayerConfigurationIdentity(path)) {
      return [];
    }
    return (json['days'] as List)
        .map((day) => PrayerDay.fromJson(Map<String, dynamic>.from(day as Map)))
        .toList();
  } catch (_) {
    return [];
  }
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
    "[$source] Exact midnight alarm scheduled: $scheduled at $nextMidnight",
  );
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
      await HomeWidget.updateWidget(
        name: "HomeAppWidgetPortraitModern",
        androidName: "HomeAppWidgetPortraitModern",
      );
      await HomeWidget.updateWidget(
        name: "HomeAppWidgetWideModern",
        androidName: "HomeAppWidgetWideModern",
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

    final days = await _readWidgetPrayerDays();
    await _publishWidgetDays(days, source: source);
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
  List<PrayerDay> days,
  String configuration, {
  bool localize = true,
}) async {
  await HomeWidget.saveWidgetData<String>(
    widgetPrayerSnapshotKey,
    jsonEncode({
      'configuration': configuration,
      'days': days.map((d) => d.toJson()).toList(),
    }),
  );
  await _publishWidgetDays(days, source: 'PrayerRefresh', localize: localize);
}

Future<void> _publishWidgetDays(
  List<PrayerDay> days, {
  required String source,
  bool localize = false,
}) async {
  final now = DateTime.now();
  final current = widgetPrayerDisplayDay(days, now: now);
  final display = current == null
      ? <String, dynamic>{}
      : await api_utils.getTimings24System(current.timings);
  final next = current == null ? null : computeNextPrayerState(days, now: now);
  for (final slot in _widgetPrayerSlots) {
    await HomeWidget.saveWidgetData<String>(
      slot.textStorageKey,
      display[slot.displayName]?.toString() ?? '-',
    );
    if (localize) {
      await HomeWidget.saveWidgetData<String>(
        '${slot.key}_label',
        slot.displayName.tr(),
      );
    }
  }
  final unavailable = localize
      ? 'Prayer_Times_Unavailable'.tr()
      : await HomeWidget.getWidgetData<String>(
              'prayer_unavailable_text',
              defaultValue: 'Prayer times unavailable for today',
            ) ??
            'Prayer times unavailable for today';
  if (localize) {
    await HomeWidget.saveWidgetData<String>(
      'prayer_unavailable_text',
      unavailable,
    );
  }
  await HomeWidget.saveWidgetData<String>(
    'prayer_data_date',
    current == null ? '' : prayerDateKey(current.date),
  );
  await HomeWidget.saveWidgetData<String>(
    'widget_calculated_date',
    prayerDateKey(now),
  );
  await HomeWidget.saveWidgetData<String>(
    'gregorianDate_text',
    current == null ? unavailable : helper.dateFormatter(current.date),
  );
  await HomeWidget.saveWidgetData<String>(
    'hijriDate_text',
    current?.dateData['hijri']?['date']?.toString() ?? '-',
  );
  await _saveNextPrayerState(next);
  await refreshWidgetOnly(source: source);
  // Even a missing-day snapshot needs another chance at the date boundary.
  await scheduleNextPrayerExactAlarm(
    next?.nextChangeTime ?? _nextMidnight(now),
    source: source,
  );
}

Future<bool> runDailyRefreshTask({String source = "unknown"}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final fetchedDate = prayerDate(DateTime.now());
  final bool shouldFetch = await helper.shouldFetchDailyData(prefs);
  if (!shouldFetch) {
    if (kDebugMode) {
      print("[$source] Daily refresh skipped (already refreshed today)");
    }
    return true;
  }

  final bool refreshed = await refreshPrayerTimesAndReschedule();
  if (refreshed) {
    await helper.updateLastFetchedDate(prefs, fetchedDate: fetchedDate);
  }
  return refreshed;
}

Future<bool> refreshPrayerTimesAndReschedule() async {
  try {
    final prefs = SharedPreferences.getInstance();
    await helper.handleNotifications(prefs, []);
    final window = await loadSavedPrayerWindow();
    if (window.date != prayerDate(DateTime.now())) return false;
    if (!kIsWeb && Platform.isAndroid) {
      await updateHomePage(window.days, window.configuration, localize: false);
    }
    final scheduled = await helper.handleNotifications(
      prefs,
      window.days,
      configuration: window.configuration,
    );
    return window.complete && scheduled;
  } catch (error, stack) {
    debugPrint('Background prayer refresh failed: $error\n$stack');
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
      final bool refreshed = await refreshWidgetOnly(
        source: "WorkManager:$task",
      );
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
