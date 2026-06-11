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

Future<void> cleanupOldPrayerTimesData(Future<SharedPreferences> sharedPreferences) async {
  try {
    final SharedPreferences prefs = await sharedPreferences;
    final DateTime now = DateTime.now();
    final DateTime cutoffDate = now.subtract(const Duration(days: 2));
    final Set<String> allKeys = prefs.getKeys();

    for (final key in allKeys) {
      if (!key.startsWith('timings')) {
        continue;
      }

      final int slashIndex = key.indexOf('/');
      if (slashIndex == -1) continue;

      final String datePart = key.substring(slashIndex + 1);
      final int questionIndex = datePart.indexOf('?');
      final String cleanDate = questionIndex != -1
          ? datePart.substring(0, questionIndex)
          : datePart;

      if (cleanDate.length != 10) continue;

      try {
        final List<String> parts = cleanDate.split('-');
        if (parts.length != 3) continue;

        final int day = int.tryParse(parts[0]) ?? 0;
        final int month = int.tryParse(parts[1]) ?? 0;
        final int year = int.tryParse(parts[2]) ?? 0;

        if (day == 0 || month == 0 || year == 0) continue;

        final DateTime storedDate = DateTime(year, month, day);

        if (storedDate.isBefore(cutoffDate)) {
          await prefs.remove(key);
          print('Cleaned up old prayer data: $key');
        }
      } catch (e) {
        print('Error parsing date from key $key: $e');
      }
    }
  } catch (e) {
    print('Error during prayer times cleanup: $e');
  }
}
