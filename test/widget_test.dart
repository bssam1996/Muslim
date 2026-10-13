import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase B status labels have intact Arabic translations', () {
    final translations =
        jsonDecode(File('assets/translations/ar-EG.json').readAsStringSync())
            as Map;
    for (final key in [
      'Prayer_Notifications_Refresh_Error',
      'Prayer_Times_Unavailable',
      'Daily_Routine_Estimated',
    ]) {
      expect(translations[key], matches(RegExp(r'[\u0600-\u06ff]')));
      expect(translations[key], isNot(contains('???')));
    }
  });

  test('translation assets include the radio page labels', () {
    final Map<String, dynamic> englishTranslations =
        jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
            as Map<String, dynamic>;
    final Map<String, dynamic> arabicTranslations =
        jsonDecode(File('assets/translations/ar-EG.json').readAsStringSync())
            as Map<String, dynamic>;

    for (final Map<String, dynamic> translations in [
      englishTranslations,
      arabicTranslations,
    ]) {
      expect(translations['Home_Panel_Radio'], isNotEmpty);
      expect(translations['Radio_Title'], isNotEmpty);
      expect(translations['Radio_Search_Hint'], isNotEmpty);
      expect(translations['Radio_Play_Error'], isNotEmpty);
      expect(translations['Settings_Tune_Title'], isNotEmpty);
      expect(translations['Settings_Tune_Desc'], isNotEmpty);
      expect(translations['Settings_Saving_Tune'], isNotEmpty);
      expect(translations['Home_Utilities_Title'], isNotEmpty);
      expect(translations['Home_Utilities_Find_Nearest_Mosque'], isNotEmpty);
      expect(translations['Nearest_Mosque_Title'], isNotEmpty);
      expect(translations['Nearest_Mosque_Open_Maps'], isNotEmpty);
    }
  });
}
