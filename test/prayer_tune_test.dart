import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/shared/constants.dart' as constants;
import 'package:muslim/utils/helper.dart' as helper;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('constructs AlAdhan tune parameter in API order', () {
    final tuneParameter = helper.constructAladhanTuneParameterFromSettings({
      'Fajr': -2,
      'Sunrise': 1,
      'Dhuhr': 3,
      'Asr': 4,
      'Maghrib': 5,
      'Isha': 6,
    });

    expect(tuneParameter, '0,-2,1,3,4,5,0,6,0');
  });

  test('adds tune parameter to constructed API path', () async {
    SharedPreferences.setMockInitialValues({
      constants.prayerTunePreferenceKey('Fajr'): -2,
      constants.prayerTunePreferenceKey('Sunrise'): 1,
      constants.prayerTunePreferenceKey('Dhuhr'): 3,
      constants.prayerTunePreferenceKey('Asr'): 4,
      constants.prayerTunePreferenceKey('Maghrib'): 5,
      constants.prayerTunePreferenceKey('Isha'): 6,
    });

    final apiPath = await helper.constructAPIParameters('', '09-03-2015', {
      'type': 'address',
      'location': 'Dubai,UAE',
    }, SharedPreferences.getInstance());

    expect(
      apiPath,
      'timingsByAddress/09-03-2015?address=Dubai,UAE'
      '&tune=0,-2,1,3,4,5,0,6,0',
    );
  });

  test(
    'uses stored coordinates for prayer-time and calendar requests',
    () async {
      SharedPreferences.setMockInitialValues({});
      const location = <String, dynamic>{
        'type': 'coordinates',
        'latitude': 51.5074,
        'longitude': -0.1278,
      };

      final timingsPath = await helper.constructAPIParameters(
        '',
        '09-03-2015',
        location,
        SharedPreferences.getInstance(),
      );
      final calendarPath = await helper.constructAPIParameters(
        'calendarByAddress',
        '03-2015',
        location,
        SharedPreferences.getInstance(),
      );

      expect(
        timingsPath,
        'timings/09-03-2015?latitude=51.5074&longitude=-0.1278'
        '&tune=0,0,0,0,0,0,0,0,0',
      );
      expect(
        calendarPath,
        'calendar/03-2015?latitude=51.5074&longitude=-0.1278'
        '&tune=0,0,0,0,0,0,0,0,0',
      );
    },
  );

  test(
    'keeps address and coordinate routes distinct while displaying city country',
    () async {
      SharedPreferences.setMockInitialValues({});
      const addressLocation = <String, dynamic>{
        'type': 'address',
        'location': '10 Downing Street, London',
        'latitude': 51.5034,
        'longitude': -0.1276,
        'cityCountry': 'London, United Kingdom',
      };

      final addressPath = await helper.constructAPIParameters(
        '',
        '09-03-2015',
        addressLocation,
        SharedPreferences.getInstance(),
      );

      expect(addressPath, contains('timingsByAddress/09-03-2015?address='));
      expect(
        helper.getAddressLocation(addressLocation),
        'London, United Kingdom',
      );
      expect(
        helper.getAddressLocation(const <String, dynamic>{
          'type': 'coordinates',
          'latitude': 51.5034,
          'longitude': -0.1276,
          'cityCountry': 'London, United Kingdom',
        }),
        'London, United Kingdom',
      );
    },
  );
}
