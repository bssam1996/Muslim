import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/dua/dua_list.dart';

void main() {
  test('Duaa contains general duas only; pilgrimage moved to Home', () {
    expect(duaItems.map((item) => item.title), ['Dua_Travel']);
  });
}
