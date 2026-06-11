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

    final apiPath = await helper.constructAPIParameters(
      '',
      '09-03-2015',
      {'type': 'address', 'location': 'Dubai,UAE'},
      SharedPreferences.getInstance(),
    );

    expect(
      apiPath,
      'timingsByAddress/09-03-2015?address=Dubai,UAE'
      '&tune=0,-2,1,3,4,5,0,6,0',
    );
  });
}
