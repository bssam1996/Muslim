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
    'date': {
      'hijri': {
        'date': '17-03-1448',
        'month': {'en': "Rabi' al-Awwal"},
      },
    },
  },
};

void main() {
  const location = <String, dynamic>{
    'type': 'address',
    'location': 'London, United Kingdom',
    'latitude': 51.5074,
    'longitude': -0.1278,
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
    expect(
      api_utils.isValidPrayerTimesResponse({
        'code': 200,
        'data': {
          'timings': validPrayerTimesResponse()['data']['timings'],
          'date': {'hijri': null},
        },
      }),
      isFalse,
    );
  });

  test(
    'sends coordinate prayer-time requests to the self-hosted API',
    () async {
      SharedPreferences.setMockInitialValues({});
      late http.Request capturedRequest;
      final http.Client client = MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(jsonEncode(validPrayerTimesResponse()), 200);
      });

      await helper.fetchData(
        '',
        '30-08-2026',
        location,
        SharedPreferences.getInstance(),
        client: client,
      );

      expect(capturedRequest.url.host, 'muslim-api-mu.vercel.app');
      expect(capturedRequest.url.path, '/v1/timings/30-08-2026');
    },
  );

  test(
    'replaces an invalid cached response with a fresh successful response',
    () async {
      SharedPreferences.setMockInitialValues({});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String date = helper.dateFormatter(DateTime.now());
      final String apiPath = (await helper.constructAPIParameters(
        '',
        date,
        location,
        Future<SharedPreferences>.value(preferences),
      ))!;
      final String cacheKey = helper.prayerTimesCacheKey(apiPath);
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
    const invalidKey = 'timings/28-08-2026?latitude=51.5074&longitude=-0.1278';
    const validKey = 'timings/29-08-2026?latitude=51.5074&longitude=-0.1278';
    SharedPreferences.setMockInitialValues({
      invalidKey: '{not valid JSON',
      validKey: jsonEncode(validPrayerTimesResponse()),
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

  test(
    'clears all prayer-time caches without changing user preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'timings/28-08-2026?latitude=51.5074': jsonEncode(
          validPrayerTimesResponse(),
        ),
        'timings-v1/29-08-2026?latitude=51.5074': jsonEncode(
          validPrayerTimesResponse(),
        ),
        'prayer-times-v1/calendar/2026/8?latitude=51.5074': jsonEncode(
          validPrayerTimesResponse(),
        ),
        'location': jsonEncode(location),
        'prayerNotificationFajr': true,
        'method': 'Muslim World League',
      });
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final int cleared = await api_utils.clearPrayerTimesCache(
        Future<SharedPreferences>.value(preferences),
      );

      expect(cleared, 3);
      expect(
        preferences.containsKey('timings/28-08-2026?latitude=51.5074'),
        isFalse,
      );
      expect(
        preferences.containsKey('timings-v1/29-08-2026?latitude=51.5074'),
        isFalse,
      );
      expect(
        preferences.containsKey(
          'prayer-times-v1/calendar/2026/8?latitude=51.5074',
        ),
        isFalse,
      );
      expect(preferences.getString('location'), jsonEncode(location));
      expect(preferences.getBool('prayerNotificationFajr'), isTrue);
      expect(preferences.getString('method'), 'Muslim World League');
    },
  );
}
