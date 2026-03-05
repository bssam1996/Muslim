import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helper.dart' as helper;
import 'shared_preference_methods.dart' as shared_preference_methods;
import 'package:seeip_client/seeip_client.dart';

Future<Map<String, dynamic>> getSavedLocation() async{
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  var savedLocation = await shared_preference_methods.getStringData(
      _prefs, 'location', true);
  if (savedLocation == null) {
    try {
      var seeip = SeeipClient();
      var ip = await seeip.getIP();
      var geoLocation = await seeip.getGeoIP(ip.ip);
      Map<String, dynamic> location = {
        "location": "${geoLocation.city}, ${geoLocation.region}, ${geoLocation.country}",
        "type": "address",
        "error": ""
      };
      bool result = await shared_preference_methods.setStringData(
          _prefs, "location", json.encode(location));
      if (!result) {
        if (kDebugMode){
          print("Location_Missing_Error".tr());
        }
        return {"error": "error while saving location"};
      }
      savedLocation = location;
    } catch (e) {
      return {"error": "error while getting location $e"};
    }
  }else{
    savedLocation["error"] = "";
  }
  return savedLocation;
}

Future<Map<String, dynamic>> getDataFromDay(int dayNumber, Map<String, dynamic> savedLocation) async{
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  dynamic jsonData;
  String? jsonEncoded = "";
  bool fetchedFromSharedPreferences = false;
  DateTime d = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + dayNumber);
  String formattedDate = helper.dateFormatter(d);
  // Construct API url from helpers
  String? sharedKey = await helper.constructAPIParameters("", formattedDate, savedLocation, _prefs);
  if (sharedKey == null){
    if (kDebugMode){
      print("Something went wrong: Couldn't construct shared key");
    }
    return {"error":"Something went wrong: Couldn't construct shared key"};
  }
  var sharedData = await shared_preference_methods.getStringData(
      _prefs, sharedKey, true);
  if (sharedData != null) {
    fetchedFromSharedPreferences = true;
    if (kDebugMode) {
      print("Fetching from shared-preferences");
    }
    jsonData = sharedData;
  } else {
    if (kDebugMode) {
      print("Fetching from API");
    }
    try{
      var r =
      await helper.fetchData("", formattedDate, savedLocation, _prefs);
      jsonEncoded = r?.body;
      jsonData = jsonDecode(jsonEncoded!);
    }catch (e){
      if (kDebugMode){
        print("Something went wrong $e");
      }
      return {"error":"Something went wrong $e"};
    }
  }
  // Save Date
  if (jsonData != null && jsonData['code'] == 200) {
    if (!fetchedFromSharedPreferences) {
      await saveDateInSharedPreference(_prefs, sharedKey, jsonEncoded);
    }
  }else{
    if (fetchedFromSharedPreferences) {
      shared_preference_methods.invalidateSharedData(_prefs, formattedDate);
    }
    return {"error":"API didn't return any data!"};
  }
  return {
    "jsonData": jsonData,
    "error": ""
  };
}

Future<bool> saveDateInSharedPreference(Future<SharedPreferences> prefs, String sharedKey, String jsonEncoded) async{
  if (kDebugMode) {
    print("Setting in shared-preferences");
  }
  bool result = await shared_preference_methods.setStringData(
      prefs, sharedKey, jsonEncoded);
  if (!result) {
    if (kDebugMode){
      print("Couldn't save data");
    }
  }
  return result;
}
Future< Map<String, dynamic>> getTimings24System(Map<String, dynamic> originalTimes) async{
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  Map<String, dynamic> timings = Map.from(originalTimes);
  var exists = await shared_preference_methods.checkExistenceData(
      _prefs, '24system');
  if (exists) {
    var shared24 =
    await shared_preference_methods.getBoolData(_prefs, '24system');
    if (shared24 != null && shared24 == false) {
      // Convert to 12 system
      originalTimes.forEach((timingName, timingValue) {
        List<String> timingWhole = timingValue.toString().split(":");
        int timingHour = int.parse(timingWhole[0]);
        int timingMinute = int.parse(timingWhole[1]);
        DateTime constructedDateTime = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            timingHour,
            timingMinute,
            DateTime.now().second);
        var newValue =
        helper.customtimeFormatter("h:mm a", constructedDateTime);
        timings[timingName] = newValue;
      });
    }
  } else {
    await shared_preference_methods.setBoolData(_prefs, '24system', true);
  }
  return timings;
}