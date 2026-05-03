import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
    }
  });
}
