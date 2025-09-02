
import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:easy_localization/easy_localization.dart' as easy_Localization;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_utils.dart' as api_utils;
import 'helper.dart' as helper;

void updateHomePage(
    Map<String, dynamic> jsonTimings, Map<String, dynamic> jsonData) async {
  Future.wait<bool?>([
    HomeWidget.saveWidgetData<String>(
        "fajr_text", jsonTimings["Fajr"].toString()),
    HomeWidget.saveWidgetData<String>("fajr_label", "Fajr".tr()),
    HomeWidget.saveWidgetData<String>(
        "sunrise_text", jsonTimings["Sunrise"].toString()),
    HomeWidget.saveWidgetData<String>("sunrise_label", "Sunrise".tr()),
    HomeWidget.saveWidgetData<String>(
        "dhuhr_text", jsonTimings["Dhuhr"].toString()),
    HomeWidget.saveWidgetData<String>("dhuhr_label", "Dhuhr".tr()),
    HomeWidget.saveWidgetData<String>(
        "asr_text", jsonTimings["Asr"].toString()),
    HomeWidget.saveWidgetData<String>("asr_label", "Asr".tr()),
    HomeWidget.saveWidgetData<String>(
        "maghrib_text", jsonTimings["Maghrib"].toString()),
    HomeWidget.saveWidgetData<String>("maghrib_label", "Maghrib".tr()),
    HomeWidget.saveWidgetData<String>(
        "isha_text", jsonTimings["Isha"].toString()),
    HomeWidget.saveWidgetData<String>("isha_label", "Isha".tr()),
    HomeWidget.saveWidgetData<String>(
        "gregorianDate_text", jsonData["gregorian"]?["date"] ?? "Month"),
    HomeWidget.saveWidgetData<String>(
        "hijriDate_text", jsonData["hijri"]?["date"] ?? "Month"),
  ]).then((value) {
    HomeWidget.updateWidget(
      name: "HomeAppWidget",
      androidName: "HomeAppWidget",
    );
    HomeWidget.updateWidget(
      name: "HomeAppWidgetWide",
      androidName: "HomeAppWidgetWide",
    );
  });
}

void onBackgroundFetch(String taskId) async {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final SharedPreferences prefs = await _prefs;
  // Your daily task logic here.
  if (await helper.shouldFetchDailyData(prefs)) {
    if (kDebugMode) {
      print("[BackgroundFetch] Fetching new daily data");
    }
    await onBackgroundFetchPrayerTimes();
  } else {
    if (kDebugMode) {
      print("[BackgroundFetch] Data already fetched today");
    }
  }
  BackgroundFetch.finish(taskId);
}

void onBackgroundFetchTimeout(String taskId) async {
  if (kDebugMode) {
    print("[BackgroundFetch] TIMEOUT: $taskId");
  }
  BackgroundFetch.finish(taskId);
}
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final SharedPreferences prefs = await _prefs;
  String taskId = task.taskId;
  bool isTimeout = task.timeout;
  if (isTimeout) {
    // This task has exceeded its allowed running-time.
    // You must stop what you're doing and immediately .finish(taskId)
    print("[BackgroundFetch] Headless task timed-out: $taskId");
    BackgroundFetch.finish(taskId);
    return;
  }
  print('[BackgroundFetch] Headless event received.');
  if (await helper.shouldFetchDailyData(prefs)) {
    if (kDebugMode) {
      print("[BackgroundFetch] Fetching new daily data");
    }
    await onBackgroundFetchPrayerTimes();
  } else {
    if (kDebugMode) {
      print("[BackgroundFetch] Data already fetched today");
    }
  }
  BackgroundFetch.finish(taskId);
}

Future<void> onBackgroundFetchPrayerTimes() async{
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final SharedPreferences prefs = await _prefs;
  Map<String, dynamic> savedLocation = await api_utils.getSavedLocation();
  if (savedLocation["error"] != ""){
    print("Error getting saved location ${savedLocation["error"]}");
    return;
  }
  dynamic jsonData;
  Map<String, dynamic> dataFromDay = await api_utils.getDataFromDay(0, savedLocation);
  if (dataFromDay["error"] != ""){
    print("Error getting date from day ${dataFromDay["error"]}");
    return;
  }
  jsonData = dataFromDay["jsonData"];

  jsonData['data']['timings'] = await api_utils.getTimings24System(jsonData['data']['timings']);
  if(!kIsWeb && Platform.isAndroid){
    updateHomePage(jsonData['data']['timings'], jsonData['data']['date']);
  }
}