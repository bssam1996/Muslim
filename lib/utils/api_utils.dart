import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/constants.dart' as constants;
import 'helper.dart' as helper;
import 'prayer_location_utils.dart';
import 'shared_preference_methods.dart' as shared_preference_methods;

Future<Map<String, dynamic>> getSavedLocation() async {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  var savedLocation = await shared_preference_methods.getStringData(
    _prefs,
    'location',
    true,
  );
  if (savedLocation == null) {
    // Do not silently use an IP-based estimate. It can point to the wrong city
    // and produce inaccurate prayer times; the user chooses a location in
    // Settings instead.
    return {"error": "Location has not been chosen"};
  }

  try {
    savedLocation = await _ensureCityCountryLabel(savedLocation, _prefs);
    savedLocation["error"] = "";
    return savedLocation;
  } on PrayerLocationException catch (error) {
    return {"error": error.translationKey};
  } catch (_) {
    return {"error": "Location could not be verified"};
  }
}

Future<Map<String, dynamic>> _ensureCityCountryLabel(
  Map<String, dynamic> savedLocation,
  Future<SharedPreferences> preferences,
) async {
  final String cityCountry = savedLocation['cityCountry']?.toString() ?? '';
  if (cityCountry.isNotEmpty) return savedLocation;

  final Map<String, dynamic> updatedLocation = Map<String, dynamic>.from(
    savedLocation,
  );
  PrayerLocation resolvedLocation;
  if (updatedLocation['type'] == 'coordinates') {
    final double? latitude = _asDouble(updatedLocation['latitude']);
    final double? longitude = _asDouble(updatedLocation['longitude']);
    if (latitude == null || longitude == null) {
      throw const PrayerLocationException(
        'Settings_Location_City_Country_Unavailable',
      );
    }
    resolvedLocation = await resolvePrayerLocationCoordinates(
      latitude,
      longitude,
      source: updatedLocation['source']?.toString() ?? 'coordinates',
    );
  } else if (updatedLocation['type'] == 'address') {
    final String address = updatedLocation['location']?.toString().trim() ?? '';
    if (address.isEmpty) {
      throw const PrayerLocationException(
        'Settings_Location_City_Country_Unavailable',
      );
    }
    final List<PrayerLocation> matches = await searchPrayerLocations(address);
    if (matches.isEmpty) {
      throw const PrayerLocationException(
        'Settings_Location_City_Country_Unavailable',
      );
    }
    resolvedLocation = await resolvePrayerLocationCoordinates(
      matches.first.latitude,
      matches.first.longitude,
      source: 'address',
    );
    updatedLocation['latitude'] = resolvedLocation.latitude;
    updatedLocation['longitude'] = resolvedLocation.longitude;
  } else {
    throw const PrayerLocationException(
      'Settings_Location_City_Country_Unavailable',
    );
  }

  updatedLocation['cityCountry'] = resolvedLocation.cityCountry;
  updatedLocation['displayName'] = resolvedLocation.displayName;
  await shared_preference_methods.setStringData(
    preferences,
    'location',
    json.encode(updatedLocation),
  );
  return updatedLocation;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool isValidPrayerTimesResponse(dynamic jsonData) {
  if (jsonData is! Map || jsonData['code'] != 200) {
    return false;
  }

  final dynamic data = jsonData['data'];
  if (data is! Map) {
    return false;
  }
  final dynamic timings = data['timings'];
  if (timings is! Map) {
    return false;
  }

  return constants.PRAYER_NAMES.every((String prayerName) {
    final dynamic value = timings[prayerName];
    return value is String && value.isNotEmpty;
  });
}

String _apiFailureMessage(http.Response response, dynamic jsonData) {
  final dynamic apiCode = jsonData is Map ? jsonData['code'] : null;
  final dynamic apiStatus = jsonData is Map ? jsonData['status'] : null;
  debugPrint(
    'Prayer-times API failed: HTTP ${response.statusCode}, '
    'API code ${apiCode ?? 'unavailable'}, status ${apiStatus ?? 'unavailable'}.',
  );

  if (response.statusCode == 429) {
    return 'Prayer-times service is busy. Please try again shortly.';
  }
  if (response.statusCode >= 500) {
    return 'Prayer-times service is temporarily unavailable. Please try again shortly.';
  }
  if (response.statusCode != 200) {
    return 'Prayer-times service rejected the request (HTTP ${response.statusCode}).';
  }
  return 'Prayer-times service returned an invalid response. Please check your location and settings.';
}

Future<Map<String, dynamic>> getDataFromDay(
  int dayNumber,
  Map<String, dynamic> savedLocation, {
  Future<SharedPreferences>? preferences,
  http.Client? client,
}) async {
  final Future<SharedPreferences> prefs =
      preferences ?? SharedPreferences.getInstance();
  DateTime d = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day + dayNumber,
  );
  String formattedDate = helper.dateFormatter(d);
  // Construct API url from helpers
  String? sharedKey = await helper.constructAPIParameters(
    "",
    formattedDate,
    savedLocation,
    prefs,
  );
  if (sharedKey == null) {
    if (kDebugMode) {
      print("Something went wrong: Couldn't construct shared key");
    }
    return {"error": "Something went wrong: Couldn't construct shared key"};
  }
  final SharedPreferences sharedPreferences = await prefs;
  final String? cachedPayload = sharedPreferences.getString(sharedKey);
  if (cachedPayload != null) {
    if (kDebugMode) {
      print("Fetching from shared-preferences");
    }
    try {
      final dynamic cachedData = jsonDecode(cachedPayload);
      if (isValidPrayerTimesResponse(cachedData)) {
        return {"jsonData": cachedData, "error": ""};
      }
    } catch (_) {
      // The malformed cache entry is removed below and replaced by fresh data.
    }
    await shared_preference_methods.invalidateSharedData(prefs, sharedKey);
    debugPrint('Removed invalid cached prayer-times response.');
  }

  if (kDebugMode) {
    print("Fetching from API");
  }

  try {
    final http.Response? response = await helper.fetchData(
      "",
      formattedDate,
      savedLocation,
      prefs,
      client: client,
    );
    if (response == null) {
      return {"error": "Couldn't construct a valid prayer-times request."};
    }

    dynamic jsonData;
    try {
      jsonData = jsonDecode(response.body);
    } catch (e) {
      debugPrint('Prayer-times API returned malformed JSON: $e');
      return {"error": _apiFailureMessage(response, null)};
    }
    if (response.statusCode == 200 && isValidPrayerTimesResponse(jsonData)) {
      await saveDateInSharedPreference(prefs, sharedKey, response.body);
      return {"jsonData": jsonData, "error": ""};
    }
    return {"error": _apiFailureMessage(response, jsonData)};
  } catch (e, stackTrace) {
    debugPrint('Prayer-times request failed: $e\n$stackTrace');
    return {
      "error":
          "Couldn't connect to the prayer-times service. Please check your connection and try again.",
    };
  }
}

Future<void> cleanupInvalidPrayerTimesData(
  Future<SharedPreferences> preferences,
) async {
  final SharedPreferences prefs = await preferences;
  for (final String key in prefs.getKeys()) {
    if (!key.startsWith('timings')) {
      continue;
    }

    final String? cachedPayload = prefs.getString(key);
    bool isValid = false;
    if (cachedPayload != null) {
      try {
        isValid = isValidPrayerTimesResponse(jsonDecode(cachedPayload));
      } catch (_) {
        isValid = false;
      }
    }
    if (!isValid) {
      await prefs.remove(key);
      debugPrint(
        'Removed invalid cached prayer-times response during cleanup.',
      );
    }
  }
}

Future<bool> saveDateInSharedPreference(
  Future<SharedPreferences> prefs,
  String sharedKey,
  String jsonEncoded,
) async {
  if (kDebugMode) {
    print("Setting in shared-preferences");
  }
  bool result = await shared_preference_methods.setStringData(
    prefs,
    sharedKey,
    jsonEncoded,
  );
  if (!result) {
    if (kDebugMode) {
      print("Couldn't save data");
    }
  }
  return result;
}

Future<Map<String, dynamic>> getTimings24System(
  Map<String, dynamic> originalTimes,
) async {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  Map<String, dynamic> timings = Map.from(originalTimes);
  var exists = await shared_preference_methods.checkExistenceData(
    _prefs,
    '24system',
  );
  if (exists) {
    var shared24 = await shared_preference_methods.getBoolData(
      _prefs,
      '24system',
    );
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
          DateTime.now().second,
        );
        var newValue = helper.customtimeFormatter(
          "h:mm a",
          constructedDateTime,
        );
        timings[timingName] = newValue;
      });
    }
  } else {
    await shared_preference_methods.setBoolData(_prefs, '24system', true);
  }
  return timings;
}
