import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/hadith/quick_hadith_card.dart';
import 'package:muslim/utils/hadith_utils.dart';

void main() {
  test('parses random hadith details and valid explanation links', () {
    final RandomHadith hadith = RandomHadith.fromJson(<String, dynamic>{
      'diacritics': 'حديث',
      'explanation': 'شرح',
      'explaination_links': <dynamic>[
        'https://example.com/one',
        <String, String>{'url': 'http://example.com/two'},
        'not a link',
      ],
    });

    expect(hadith.hadith, 'حديث');
    expect(hadith.explanation, 'شرح');
    expect(hadith.explanationLinks, <String>[
      'https://example.com/one',
      'http://example.com/two',
    ]);
  });

  testWidgets('opens hadith details with explanation and links', (
    WidgetTester tester,
  ) async {
    const RandomHadith hadith = RandomHadith(
      hadith: 'حديث اليوم',
      explanation: 'شرح الحديث',
      explanationLinks: <String>['https://example.com/details'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: QuickHadithCardPageClass(hadith: hadith)),
      ),
    );

    await tester.tap(find.text('حديث اليوم'));
    await tester.pumpAndSettle();

    expect(find.text('شرح الحديث'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });
}
