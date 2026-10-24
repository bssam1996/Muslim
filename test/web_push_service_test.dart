import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/utils/web_push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'web settings preserve Android alarm preferences and calculation options',
    () async {
      final android = {
        'prayerNotification': true,
        'prayerNotificationFajr': false,
        'prayerNotificationModeFajr': 'custom_sound',
        'prayerNotificationSoundFajr': 'adhan',
      };
      SharedPreferences.setMockInitialValues({
        ...android,
        'location': jsonEncode({'latitude': 51.5074, 'longitude': -0.1278}),
        'method': 'Muslim World League',
        'school': 'Hanafi',
        'prayerTimeTuneFajr': 2,
        webPushPrayersKey: ['Fajr', 'Isha'],
      });
      final prefs = await SharedPreferences.getInstance();
      final data = await const WebPushService().configuration(
        prefs,
        language: 'ar',
      );
      expect(data['locale'], 'ar');
      expect(data['prayers'], ['Fajr', 'Isha']);
      final query = data['query'] as Map;
      expect(query['method'], '3');
      expect(query['school'], '1');
      expect(query['tune'], '0,2,0,0,0,0,0,0,0');
      for (final entry in android.entries) {
        expect(prefs.get(entry.key), entry.value);
      }
    },
  );

  test('web enabling requires an explicitly saved prayer location', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
      const WebPushService().configuration(prefs),
      throwsA(
        isA<WebPushException>().having(
          (error) => error.code,
          'code',
          'location_required',
        ),
      ),
    );
  });
}
