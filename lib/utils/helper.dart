import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/shared_preference_methods.dart' as shared_preference_methods;
import '../shared/constants.dart' as constants;
import 'notification_service.dart';

const String _lastFetchedDateKey = 'last_fetched_date';

String dateFormatter(DateTime d){
  DateFormat formatter = DateFormat('dd-MM-yyyy');
  String formattedDate = formatter.format(d);
  return formattedDate;
}

String customtimeFormatter(String customFormat,DateTime d){
  DateFormat formatter = DateFormat(customFormat);
  String formattedDate = formatter.format(d);
  return formattedDate;
}

Future<String?> constructAPIParameters(String callType, String requiredDate, Map<String,dynamic> location, Future<SharedPreferences> prefs) async{
  try{
    String constructedParameters = "";

    if(callType == ""){
      if(location["type"] != "address"){
        callType = "timings";
        return null;
      }else{
        callType = "timingsByAddress";
        constructedParameters = 'address=${location["location"]}';
      }
    }else if(callType=="calendarByAddress"){
      constructedParameters = 'address=${location["location"]}';
    }
    var sharedMethod = await shared_preference_methods.getStringData(
        prefs, "method", false);
    if(sharedMethod != null && sharedMethod != "" && sharedMethod != "Default"){
      String mappedMethod = constants.authorities[sharedMethod].toString();
      constructedParameters = '$constructedParameters&method=$mappedMethod';
    }
    var sharedSchool = await shared_preference_methods.getStringData(
        prefs, "school", false);
    if(sharedSchool != null && sharedSchool != ""){
      String mappedSchool = constants.schools[sharedSchool].toString();
      constructedParameters = '$constructedParameters&school=$mappedSchool';
    }
    var calendarMethod = await shared_preference_methods.getStringData(
        prefs, "calendarMethod", false);
    if(calendarMethod != null && calendarMethod != ""){
      String mappedCalendarMethod = constants.CalendarMethods[calendarMethod].toString();
      constructedParameters = '$constructedParameters&calendarMethod=$mappedCalendarMethod';
      if (calendarMethod.toString() == "MATHEMATICAL") {
        var sharedAdjustment = await shared_preference_methods.getIntegerData(
        prefs, "adjustment", 1);
        if(sharedAdjustment != null){
          constructedParameters = '$constructedParameters&adjustment=${sharedAdjustment.toString()}';
        }
      }
    }


    return '$callType/$requiredDate?$constructedParameters';
  }catch(e){
    if (kDebugMode) {
      print(e);
    }
    return null;
  }
}
Future<http.Response?>? fetchData(String callType, String requiredDate, Map<String,dynamic> location, Future<SharedPreferences> prefs) async{
  try{
    String? constructedParameters = await constructAPIParameters(callType, requiredDate, location, prefs);
    if(constructedParameters == null){
      return null;
    }
    return http.get(Uri.parse('https://api.aladhan.com/v1/$constructedParameters'));
  }catch(e){
    if (kDebugMode) {
      print(e);
    }
    return null;
  }
}

void invalidateTodayCachedData(Future<SharedPreferences> prefs) async{
  String formattedDate = dateFormatter(DateTime.now());
  var exists = await shared_preference_methods.checkExistenceData(
      prefs, formattedDate);
  if(exists){
    shared_preference_methods.invalidateSharedData(prefs, formattedDate);
  }
}


DateTime constructDateTime(String timeString){
  List<String> timingWhole = timeString.toString().split(":");
  int timingHour = int.parse(timingWhole[0]);
  int timingMinute = int.parse(timingWhole[1]);
  DateTime constructedDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      timingHour,
      timingMinute,
      0);
  return constructedDateTime;
}

String constructTimeLeft(Duration? duration){
  if(duration == null){
    return "-";
  }
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
}

String constructTimeLeftSplitted(Duration? duration, String type){
  if(duration == null){
    return "-";
  }
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  if(type == "hour"){
    return twoDigits(duration.inHours);
  }else if(type == "minute"){
    return twoDigitMinutes;
  }else if(type == "second"){
    return twoDigitSeconds;
  }else{
    return "-";
  }
}


MaterialColor getMaterialColor(Color color) {
  final int red = color.red;
  final int green = color.green;
  final int blue = color.blue;

  final Map<int, Color> shades = {
    50: Color.fromRGBO(red, green, blue, .1),
    100: Color.fromRGBO(red, green, blue, .2),
    200: Color.fromRGBO(red, green, blue, .3),
    300: Color.fromRGBO(red, green, blue, .4),
    400: Color.fromRGBO(red, green, blue, .5),
    500: Color.fromRGBO(red, green, blue, .6),
    600: Color.fromRGBO(red, green, blue, .7),
    700: Color.fromRGBO(red, green, blue, .8),
    800: Color.fromRGBO(red, green, blue, .9),
    900: Color.fromRGBO(red, green, blue, 1),
  };

  return MaterialColor(color.value, shades);
}

Future<bool> shouldFetchDailyData(SharedPreferences prefs) async {
  final String? lastFetchedDateString = prefs.getString(_lastFetchedDateKey);
  if (lastFetchedDateString == null) {
    return true; // Never fetched before
  }
  final DateTime lastFetchedDate = DateTime.parse(lastFetchedDateString);
  final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  return !lastFetchedDate.isAtSameMomentAs(today);
}

Future<void> updateLastFetchedDate(SharedPreferences prefs) async {
  final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  await prefs.setString(_lastFetchedDateKey, today.toIso8601String());
}
String getNowMinutes(){
  DateTime now = DateTime.now();
  return now.minute.toString().padLeft(2, '0');
}

String getAddressLocation(Map<String, dynamic> savedLocation){
  if(savedLocation["type"] == "address"){
    return savedLocation["location"]??"-";
  }else{
    return "-";
  }
}

String constructDateFormat(String month, String fullDate){
  List<String> fullDateSplitted = fullDate.split("-");
  if(fullDateSplitted.length != 3){
    return "Month";
  }
  String year = fullDateSplitted[2];
  String monthNum = fullDateSplitted[1];
  String day = fullDateSplitted[0];
  // month = month.tr();
  return "$day-$monthNum-$year";
}
Future<void> handleNotifications(Future<SharedPreferences> prefs, List<Map<String, dynamic>> jsonTimings) async {
  var sharedprayerNotification = await shared_preference_methods.checkExistenceData(prefs, 'prayerNotification');
  var prayerNotificationValue = false;
  if(sharedprayerNotification){
    var prayerNotificationSettings = await shared_preference_methods.getBoolData(prefs, 'prayerNotification');
    prayerNotificationValue = prayerNotificationSettings;
  }else{
    return;
  }
  if (!prayerNotificationValue){
    return;
  }
  try{
    await NotificationService().init();
    // NotificationService().clearAllNotifications();
    for (int i = 0; i < constants.PRAYER_NAMES.length; i++) {
      if (i == 1){
        continue; // Skip Sunrise
      }
      String time = jsonTimings[0][constants.PRAYER_NAMES[i]];
      final String lowerTime = time.toLowerCase();
      bool is24HourSystem = !lowerTime.contains("m");
      bool isPm = false;
      if (!is24HourSystem) {
        isPm = lowerTime.contains("pm");
        time = lowerTime.replaceAll(" am", "").replaceAll(" pm", "");
      }
      List<String> splittedTime = time.split(":");
      String hourString = splittedTime[0];
      String minuteString = splittedTime[1];
      if(!is24HourSystem){
        int parsedHour = int.parse(hourString) % 12;
        if (isPm) {
          parsedHour += 12;
        }
        hourString = parsedHour.toString();
      }
      DateTime selectedTime = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          int.parse(hourString),
          int.parse(minuteString),
          0);
      if(selectedTime.isBefore(DateTime.now())){
        continue;
      }
      var r = await NotificationService().scheduleDailyNotification(selectedTime, i, "Muslim", constants.PRAYER_NAMES[i], "${"Don't forget praying".tr()} ${constants.PRAYER_NAMES[i].tr()}");
      if (r != ""){
        if (kDebugMode) {
          print(r);
        }return;
      }
    }

    return;
  }catch (e){
    if (kDebugMode) {
      print(e.toString());

    }return;
  }
}
