import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/shared_preference_methods.dart' as shared_preference_methods;
import '../shared/constants.dart' as constants;
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
Future<http.Response?>? fetchData(String requiredDate, Map<String,dynamic> location, Future<SharedPreferences> prefs) async{
  try{
    String constructedParameters = "";
    String callType = "";
    if(location["type"] != "address"){
      callType = "timings";
      return null;
    }else{
      callType = "timingsByAddress";
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
    var sharedAdjustment = await shared_preference_methods.getIntegerData(
        prefs, "adjustment", 1);
    if(sharedAdjustment != null){
      constructedParameters = '$constructedParameters&adjustment=${sharedAdjustment.toString()}';
    }
    return http.get(Uri.parse('https://api.aladhan.com/v1/$callType/$requiredDate?$constructedParameters'));
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