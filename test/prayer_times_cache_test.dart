import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim/utils/api_utils.dart' as api_utils;
import 'package:muslim/utils/helper.dart' as helper;
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> validPrayerTimesResponse() => {
  'code': 200,
  'status': 'OK',
  'data': {
    'timings': {
      'Fajr': '05:00',
      'Sunrise': '06:30',
      'Dhuhr': '12:15',
      'Asr': '15:30',
      'Maghrib': '18:00',
      'Isha': '19:30',
    },
  },
};

void main() {
  const location = <String, dynamic>{
    'type': 'address',
    'location': 'London, United Kingdom',
  };

  test('recognizes only complete successful prayer-time responses', () {
    expect(
      api_utils.isValidPrayerTimesResponse(validPrayerTimesResponse()),
      isTrue,
    );
    expect(api_utils.isValidPrayerTimesResponse({'code': 500}), isFalse);
    expect(
      api_utils.isValidPrayerTimesResponse({
        'code': 200,
        'data': {
          'timings': {'Fajr': '05:00'},
        },
      }),
      isFalse,
    );
  });

  test(
    'replaces an invalid cached response with a fresh successful response',
    () async {
      SharedPreferences.setMockInitialValues({});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String date = helper.dateFormatter(DateTime.now());
      final String cacheKey = (await helper.constructAPIParameters(
        '',
        date,
        location,
        Future<SharedPreferences>.value(preferences),
      ))!;
      await preferences.setString(cacheKey, jsonEncode({'code': 503}));

      int requestCount = 0;
      final http.Client client = MockClient((http.Request request) async {
        requestCount++;
        return http.Response(jsonEncode(validPrayerTimesResponse()), 200);
      });

      final Map<String, dynamic> result = await api_utils.getDataFromDay(
        0,
        location,
        preferences: Future<SharedPreferences>.value(preferences),
        client: client,
      );

      expect(result['error'], isEmpty);
      expect(requestCount, 1);
      expect(
        jsonDecode(preferences.getString(cacheKey)!),
        validPrayerTimesResponse(),
      );
    },
  );

  test(
    'returns a clear message when the prayer-times service is unavailable',
    () async {
      SharedPreferences.setMockInitialValues({});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final http.Client client = MockClient((http.Request request) async {
        return http.Response(jsonEncode({'code': 503, 'status': 'ERROR'}), 503);
      });

      final Map<String, dynamic> result = await api_utils.getDataFromDay(
        0,
        location,
        preferences: Future<SharedPreferences>.value(preferences),
        client: client,
      );

      expect(result['error'], contains('temporarily unavailable'));
    },
  );

  test('startup cleanup removes malformed prayer-time cache entries', () async {
    const invalidKey = 'timingsByAddress/28-08-2026?address=London';
    const validKey = 'timingsByAddress/29-08-2026?address=London';
    SharedPreferences.setMockInitialValues({
      invalidKey: '{not valid JSON',
      validKey: jsonEncode({
        'code': 200,
        'data': {
          'timings': {
            'Fajr': '05:00',
            'Sunrise': '06:30',
            'Dhuhr': '12:15',
            'Asr': '15:30',
            'Maghrib': '18:00',
            'Isha': '19:30',
          },
        },
      }),
      'unrelatedSetting': 'preserved',
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await api_utils.cleanupInvalidPrayerTimesData(
      Future<SharedPreferences>.value(preferences),
    );

    expect(preferences.containsKey(invalidKey), isFalse);
    expect(preferences.containsKey(validKey), isTrue);
    expect(preferences.getString('unrelatedSetting'), 'preserved');
  });
}
