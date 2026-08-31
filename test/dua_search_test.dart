import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/dua/dua_search.dart';

void main() {
  test('matches English and Arabic search terms', () {
    const String titleKey = 'Dua_Makkah_To_Mina';

    expect(
      DuaSearch.matches('makkah mina', DuaSearch.titleTerms(titleKey)),
      isTrue,
    );
    expect(DuaSearch.matches('مكة', DuaSearch.titleTerms(titleKey)), isTrue);
  });

  test('ignores Arabic diacritics and requires every search term', () {
    const List<String> searchableTexts = <String>['اللَّهُمَّ اغفر لي'];

    expect(DuaSearch.matches('اللهم اغفر', searchableTexts), isTrue);
    expect(DuaSearch.matches('اللهم سفر', searchableTexts), isFalse);
  });
}
