import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
Future<http.Response>? fetchData(String requiredData, String location) {
  try{
    return http.get(Uri.parse('https://api.aladhan.com/v1/timingsByAddress/$requiredData?address=$location'));
  }catch(e){
    if (kDebugMode) {
      print(e);
    }
    return null;
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
      DateTime.now().second);
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