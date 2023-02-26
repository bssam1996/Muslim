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