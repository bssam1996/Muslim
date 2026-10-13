import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/shared_preference_methods.dart' as shared_preference_methods;
import '../shared/constants.dart' as constants;
import 'notification_service.dart';
import 'prayer_schedule.dart';
import 'prayer_alarm_scheduler.dart';

const String _lastFetchedDateKey = 'last_fetched_date';

String _appendQueryParameter(String constructedParameters, String parameter) {
  if (constructedParameters.isEmpty) {
    return parameter;
  }
  return '$constructedParameters&$parameter';
}

String dateFormatter(DateTime d) {
  DateFormat formatter = DateFormat('dd-MM-yyyy');
  String formattedDate = formatter.format(d);
  return formattedDate;
}

String customtimeFormatter(String customFormat, DateTime d) {
  DateFormat formatter = DateFormat(customFormat);
  String formattedDate = formatter.format(d);
  return formattedDate;
}

Future<String?> constructAPIParameters(
  String callType,
  String requiredDate,
  Map<String, dynamic> location,
  Future<SharedPreferences> prefs,
) async {
  try {
    String constructedParameters = "";
    final bool hasCoordinates =
        location["latitude"] is num && location["longitude"] is num;

    if (callType == "") {
      if (!hasCoordinates) return null;
      callType = "timings";
      constructedParameters =
          'latitude=${location["latitude"]}&longitude=${location["longitude"]}';
    } else if (callType == "calendar") {
      if (!hasCoordinates) return null;
      constructedParameters =
          'latitude=${location["latitude"]}&longitude=${location["longitude"]}';
    }
    var sharedMethod = await shared_preference_methods.getStringData(
      prefs,
      "method",
      false,
    );
    if (sharedMethod != null &&
        sharedMethod != "" &&
        sharedMethod != "Default") {
      String mappedMethod = constants.authorities[sharedMethod].toString();
      constructedParameters = '$constructedParameters&method=$mappedMethod';
    }
    var sharedSchool = await shared_preference_methods.getStringData(
      prefs,
      "school",
      false,
    );
    if (sharedSchool != null && sharedSchool != "") {
      String mappedSchool = constants.schools[sharedSchool].toString();
      constructedParameters = '$constructedParameters&school=$mappedSchool';
    }
    var calendarMethod = await shared_preference_methods.getStringData(
      prefs,
      "calendarMethod",
      false,
    );
    if (calendarMethod != null && calendarMethod != "") {
      String mappedCalendarMethod = constants.CalendarMethods[calendarMethod]
          .toString();
      constructedParameters =
          '$constructedParameters&calendarMethod=$mappedCalendarMethod';
      if (calendarMethod.toString() == "MATHEMATICAL") {
        var sharedAdjustment = await shared_preference_methods.getIntegerData(
          prefs,
          "adjustment",
          1,
        );
        if (sharedAdjustment != null) {
          constructedParameters =
              '$constructedParameters&adjustment=${sharedAdjustment.toString()}';
        }
      }
    }
    final String tuneParameter = await constructAladhanTuneParameter(prefs);
    constructedParameters = _appendQueryParameter(
      constructedParameters,
      'tune=$tuneParameter',
    );

    return '$callType/$requiredDate?$constructedParameters';
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return null;
  }
}

Future<Map<String, int>> getPrayerTimeTuneSettings(
  Future<SharedPreferences> prefs,
) async {
  final Map<String, int> tuneSettings = {};
  for (final prayerName in constants.PRAYER_NAMES) {
    final int tuneValue =
        await shared_preference_methods.getIntegerData(
          prefs,
          constants.prayerTunePreferenceKey(prayerName),
          0,
        ) ??
        0;
    tuneSettings[prayerName] = tuneValue;
  }
  return tuneSettings;
}

String constructAladhanTuneParameterFromSettings(
  Map<String, int> tuneSettings,
) {
  return constants.aladhanTuneParameterOrder
      .map((prayerName) {
        if (constants.PRAYER_NAMES.contains(prayerName)) {
          return (tuneSettings[prayerName] ?? 0).toString();
        }
        return '0';
      })
      .join(',');
}

Future<String> constructAladhanTuneParameter(
  Future<SharedPreferences> prefs,
) async {
  final Map<String, int> tuneSettings = await getPrayerTimeTuneSettings(prefs);
  return constructAladhanTuneParameterFromSettings(tuneSettings);
}

/// Separates locally cached AlAdhan payloads from responses calculated by the
/// self-hosted Muslim API while retaining the full coordinate/settings query.
String prayerTimesCacheKey(String apiPath) {
  if (apiPath.startsWith('timings/')) {
    return apiPath.replaceFirst('timings/', 'timings-v1/');
  }
  return 'prayer-times-v1/$apiPath';
}

Future<http.Response?> fetchData(
  String callType,
  String requiredDate,
  Map<String, dynamic> location,
  Future<SharedPreferences> prefs, {
  http.Client? client,
}) async {
  String? constructedParameters = await constructAPIParameters(
    callType,
    requiredDate,
    location,
    prefs,
  );
  if (constructedParameters == null) {
    return null;
  }

  final Uri uri = Uri.parse(
    '${constants.prayerTimesApiUrl}$constructedParameters',
  );
  return (client?.get(uri) ?? http.get(uri)).timeout(
    const Duration(seconds: 15),
  );
}

Future<void> invalidateTodayCachedData(Future<SharedPreferences> prefs) async {
  String formattedDate = dateFormatter(DateTime.now());
  final SharedPreferences sharedPrefs = await prefs;
  final String dateSegment = '/$formattedDate';
  for (final key in sharedPrefs.getKeys()) {
    if (!key.startsWith('timings') || !key.contains(dateSegment)) {
      continue;
    }
    await sharedPrefs.remove(key);
  }
  await sharedPrefs.remove(_lastFetchedDateKey);
}

DateTime constructDateTime(String timeString) {
  List<String> timingWhole = timeString.toString().split(":");
  int timingHour = int.parse(timingWhole[0]);
  int timingMinute = int.parse(timingWhole[1]);
  DateTime constructedDateTime = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    timingHour,
    timingMinute,
    0,
  );
  return constructedDateTime;
}

String constructTimeLeft(Duration? duration) {
  if (duration == null) {
    return "-";
  }
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
}

String constructTimeLeftSplitted(Duration? duration, String type) {
  if (duration == null) {
    return "-";
  }
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  if (type == "hour") {
    return twoDigits(duration.inHours);
  } else if (type == "minute") {
    return twoDigitMinutes;
  } else if (type == "second") {
    return twoDigitSeconds;
  } else {
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
  final DateTime? lastFetchedDate = DateTime.tryParse(lastFetchedDateString);
  if (lastFetchedDate == null) return true;
  final DateTime today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  return !lastFetchedDate.isAtSameMomentAs(today);
}

Future<void> updateLastFetchedDate(
  SharedPreferences prefs, {
  DateTime? fetchedDate,
}) async {
  await prefs.setString(
    _lastFetchedDateKey,
    prayerDate(fetchedDate ?? DateTime.now()).toIso8601String(),
  );
}

String getNowMinutes() {
  DateTime now = DateTime.now();
  return now.minute.toString().padLeft(2, '0');
}

String getAddressLocation(Map<String, dynamic> savedLocation) {
  if (savedLocation["type"] == "coordinates") {
    return savedLocation["cityCountry"] ??
        savedLocation["displayName"] ??
        '${savedLocation["latitude"]}, ${savedLocation["longitude"]}';
  } else if (savedLocation["type"] == "address") {
    return savedLocation["cityCountry"] ?? savedLocation["location"] ?? "-";
  } else {
    return "-";
  }
}

String constructDateFormat(String month, String fullDate) {
  List<String> fullDateSplitted = fullDate.split("-");
  if (fullDateSplitted.length != 3) {
    return "Month";
  }
  String year = fullDateSplitted[2];
  String monthNum = fullDateSplitted[1];
  String day = fullDateSplitted[0];
  // month = month.tr();
  return "$day-$monthNum-$year";
}

Future<Map<String, bool>> getPrayerNotificationSettings(
  Future<SharedPreferences> prefs,
  bool defaultValue,
) async {
  final Map<String, bool> notificationSettings = {};
  for (final prayerName in constants.PRAYER_NOTIFICATION_NAMES) {
    final String preferenceKey = constants.prayerNotificationPreferenceKey(
      prayerName,
    );
    final bool preferenceExists = await shared_preference_methods
        .checkExistenceData(prefs, preferenceKey);
    bool enabled = defaultValue;
    if (preferenceExists) {
      enabled =
          await shared_preference_methods.getBoolData(prefs, preferenceKey) ??
          defaultValue;
    } else {
      await shared_preference_methods.setBoolData(
        prefs,
        preferenceKey,
        defaultValue,
      );
    }
    notificationSettings[prayerName] = enabled;
  }
  return notificationSettings;
}

Future<Map<String, String>> getPrayerNotificationModes(
  Future<SharedPreferences> prefs,
) async {
  final Map<String, String> modeSettings = {};
  for (final prayerName in constants.PRAYER_NOTIFICATION_NAMES) {
    final String preferenceKey = constants.prayerNotificationModePreferenceKey(
      prayerName,
    );
    final bool preferenceExists = await shared_preference_methods
        .checkExistenceData(prefs, preferenceKey);
    String modeValue = constants.prayerNotificationModeVibrationOnly;
    if (preferenceExists) {
      modeValue =
          await shared_preference_methods.getStringData(
            prefs,
            preferenceKey,
            false,
          ) ??
          constants.prayerNotificationModeVibrationOnly;
    } else {
      await shared_preference_methods.setStringData(
        prefs,
        preferenceKey,
        modeValue,
      );
    }
    modeSettings[prayerName] = modeValue;
  }
  return modeSettings;
}

Future<Map<String, String>> getPrayerNotificationSounds(
  Future<SharedPreferences> prefs,
) async {
  final Map<String, String> soundSettings = {};
  for (final prayerName in constants.PRAYER_NOTIFICATION_NAMES) {
    final String preferenceKey = constants.prayerNotificationSoundPreferenceKey(
      prayerName,
    );
    final bool preferenceExists = await shared_preference_methods
        .checkExistenceData(prefs, preferenceKey);
    String soundValue = "";
    if (preferenceExists) {
      soundValue =
          await shared_preference_methods.getStringData(
            prefs,
            preferenceKey,
            false,
          ) ??
          "";
    }
    final String normalizedValue = constants.adhanSoundKeyFromStoredValue(
      soundValue,
    );
    if (!preferenceExists || normalizedValue != soundValue) {
      await shared_preference_methods.setStringData(
        prefs,
        preferenceKey,
        normalizedValue,
      );
    }
    soundSettings[prayerName] = normalizedValue;
  }
  return soundSettings;
}

Future<bool> handleNotifications(
  Future<SharedPreferences> prefs,
  List<PrayerDay> days, {
  String configuration = '',
  PrayerAlarmBackend? backend,
  DateTime? now,
}) async {
  if (backend == null && (kIsWeb || !Platform.isAndroid)) return true;
  try {
    final preferences = await prefs;
    await preferences.reload();
    String notificationSettingsSnapshot() {
      final keys =
          preferences
              .getKeys()
              .where(
                (key) =>
                    key.startsWith('prayerNotification') ||
                    key.startsWith('prayerTimeTune') ||
                    [
                      'location',
                      'method',
                      'school',
                      'calendarMethod',
                      'adjustment',
                    ].contains(key),
              )
              .toList()
            ..sort();
      return keys.map((key) => '$key=${preferences.get(key)}').join('|');
    }

    final modes = await getPrayerNotificationModes(prefs);
    final configuredSounds = await getPrayerNotificationSounds(prefs);
    final capturedSettings = notificationSettingsSnapshot();
    final masterEnabled = preferences.getBool('prayerNotification') ?? false;
    final enabled = {
      for (final name in constants.PRAYER_NOTIFICATION_NAMES)
        name:
            masterEnabled &&
            (preferences.getBool(
                  constants.prayerNotificationPreferenceKey(name),
                ) ??
                masterEnabled),
    };
    final sounds = <String, String?>{};
    final channels = <String, String>{};
    for (final name in constants.PRAYER_NOTIFICATION_NAMES) {
      final mode =
          preferences.getString(
            constants.prayerNotificationModePreferenceKey(name),
          ) ??
          modes[name] ??
          constants.prayerNotificationModeVibrationOnly;
      final soundKey =
          preferences.getString(
            constants.prayerNotificationSoundPreferenceKey(name),
          ) ??
          configuredSounds[name] ??
          '';
      final sound =
          mode == constants.prayerNotificationModeCustomSound &&
              soundKey.isNotEmpty
          ? constants.androidRawResourceNameFromSoundKey(soundKey)
          : null;
      sounds[name] = sound;
      channels[name] = constants.prayerNotificationAndroidChannelId(
        name,
        mode,
        sound,
      );
    }
    return await PrayerAlarmReconciler(
      preferences,
      backend ?? NotificationService(),
    ).reconcile(
      days: days,
      configuration: configuration,
      enabled: enabled,
      channels: channels,
      sounds: sounds,
      now: now ?? DateTime.now(),
      stillCurrent: () async {
        await preferences.reload();
        if (capturedSettings != notificationSettingsSnapshot()) return false;
        if (backend == null && configuration.isNotEmpty) {
          final location =
              jsonDecode(preferences.getString('location') ?? '{}')
                  as Map<String, dynamic>;
          final path = await constructAPIParameters(
            '',
            dateFormatter(now ?? DateTime.now()),
            location,
            prefs,
          );
          if (path == null ||
              prayerConfigurationIdentity(path) != configuration) {
            return false;
          }
        }
        return capturedSettings == notificationSettingsSnapshot();
      },
    );
  } catch (error, stack) {
    debugPrint('Prayer alarm update failed: $error\n$stack');
    return false;
  }
}

Future<bool> networkAccess() async {
  try {
    final result = await InternetAddress.lookup('example.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}
