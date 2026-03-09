import 'dart:io';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'api_utils.dart' as api_utils;
import 'helper.dart' as helper;

const String dailyRefreshUniqueName = 'daily_prayer_refresh';
const String dailyRefreshTaskName = 'Refresh_Notification_Prayer_Times';

Future<void> updateHomePage(
  Map<String, dynamic> jsonTimings,
  Map<String, dynamic> jsonData,
) async {
  await Future.wait<bool?>([
    HomeWidget.saveWidgetData<String>("fajr_text", jsonTimings["Fajr"].toString()),
    HomeWidget.saveWidgetData<String>("fajr_label", "Fajr".tr()),
    HomeWidget.saveWidgetData<String>(
      "sunrise_text",
      jsonTimings["Sunrise"].toString(),
    ),
    HomeWidget.saveWidgetData<String>("sunrise_label", "Sunrise".tr()),
    HomeWidget.saveWidgetData<String>("dhuhr_text", jsonTimings["Dhuhr"].toString()),
    HomeWidget.saveWidgetData<String>("dhuhr_label", "Dhuhr".tr()),
    HomeWidget.saveWidgetData<String>("asr_text", jsonTimings["Asr"].toString()),
    HomeWidget.saveWidgetData<String>("asr_label", "Asr".tr()),
    HomeWidget.saveWidgetData<String>(
      "maghrib_text",
      jsonTimings["Maghrib"].toString(),
    ),
    HomeWidget.saveWidgetData<String>("maghrib_label", "Maghrib".tr()),
    HomeWidget.saveWidgetData<String>("isha_text", jsonTimings["Isha"].toString()),
    HomeWidget.saveWidgetData<String>("isha_label", "Isha".tr()),
    HomeWidget.saveWidgetData<String>(
      "gregorianDate_text",
      jsonData["gregorian"]?["date"] ?? "Month",
    ),
    HomeWidget.saveWidgetData<String>(
      "hijriDate_text",
      jsonData["hijri"]?["date"] ?? "Month",
    ),
  ]);

  await HomeWidget.updateWidget(
    name: "HomeAppWidget",
    androidName: "HomeAppWidget",
  );
  await HomeWidget.updateWidget(
    name: "HomeAppWidgetWide",
    androidName: "HomeAppWidgetWide",
  );
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
    final Map<String, dynamic> savedLocation = await api_utils.getSavedLocation();
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
      await updateHomePage(jsonData['data']['timings'], jsonData['data']['date']);
      final List<Map<String, dynamic>> jsonTimings = [jsonData['data']['timings']];
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
    return runDailyRefreshTask(source: "WorkManager:$task");
  });
}
