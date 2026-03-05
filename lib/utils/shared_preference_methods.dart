import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void invalidateSharedData(Future<SharedPreferences> sharedPreferences,String name) async {
  try {
    final SharedPreferences prefs = await sharedPreferences;
    final success = await prefs.remove(name);
    if (kDebugMode) {
      if (success) {
        print("Removed from sharedPreferences");
      } else {
        print("Couldn't remove from sharedPreferences");
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
  }
}

Future<dynamic> getStringData(Future<SharedPreferences> sharedPreferences, String data, bool decode) async {
  try {
    final SharedPreferences prefs = await sharedPreferences;
    final String? sharedData = prefs.getString(data);
    return (decode && sharedData != null)?json.decode(sharedData):sharedData;
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return null;
  }
}

Future<bool> setStringData(Future<SharedPreferences> sharedPreferences, String key, String value) async {
  try {
    final SharedPreferences prefs = await sharedPreferences;
    await prefs.setString(key, value);
    return true;
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return false;
  }
}

Future<dynamic> getBoolData(Future<SharedPreferences> sharedPreferences, String data) async {
  try {
    final SharedPreferences prefs = await sharedPreferences;
    final bool? sharedData = prefs.getBool(data);
    return sharedData;
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return null;
  }
}

Future<bool> setBoolData(Future<SharedPreferences> sharedPreferences, String key, bool value) async {
  try {
    final SharedPreferences prefs = await sharedPreferences;
    await prefs.setBool(key, value);
    return true;
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return false;
  }
}

Future<dynamic> getIntegerData(Future<SharedPreferences> sharedPreferences, String data, int def) async {
  try {
    final SharedPreferences prefs = await sharedPreferences;
    final int? sharedData = prefs.getInt(data);
    return (sharedData != null)?sharedData:def;
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return null;
  }
}

Future<bool> setIntegerData(Future<SharedPreferences> sharedPreferences, String key, int value) async {
  try {
    final SharedPreferences prefs = await sharedPreferences;
    await prefs.setInt(key, value);
    return true;
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return false;
  }
}

Future<bool> checkExistenceData(Future<SharedPreferences> sharedPreferences, String key) async {
  try {
    final SharedPreferences prefs = await sharedPreferences;
    return prefs.containsKey(key);
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return false;
  }
}
