import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/dua/dua_list.dart';

void main() {
  test('groups general, Umrah, and Hajj duas into the correct pages', () {
    expect(duaItems.map((item) => item.title), <String>[
      'Dua_Travel',
      'Dua_Umrah',
      'Dua_Hajj',
    ]);
    expect(umrahDuaItems.map((item) => item.title), <String>[
      'Dua_Umrah_Talbiyah',
      'Dua_Umrah_Tawaf',
      'Dua_Umrah_Sai',
    ]);
    expect(
      hajjDuaItems.map((item) => item.title),
      contains('Dua_Hajj_Finishing'),
    );
    expect(
      hajjDuaItems.map((item) => item.title),
      isNot(contains('Dua_Travel')),
    );
  });
}
