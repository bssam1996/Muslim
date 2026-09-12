import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muslim/UI/azkar/azkar_card_page.dart';
import 'package:muslim/UI/azkar/azkar_items.dart';
import 'package:muslim/UI/azkar/azkar_list.dart';
import 'package:muslim/UI/azkar/azkar_page.dart';
import 'package:muslim/UI/azkar/azkar_session.dart';
import 'package:muslim/UI/azkar/azkar_style.dart';

Widget azkarHost(Widget child, {bool arabic = false}) => MaterialApp(
  locale: Locale(arabic ? 'ar' : 'en'),
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
}

List<AzkarItem> sampleItems() => [
  AzkarItem(data: 'First', count: 3),
  AzkarItem(data: 'Second', count: 1),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'all existing categories have icons and safe, unique counter identities',
    () {
      for (final entry in AzkarCategories.entries) {
        expect(azkarIcons.containsKey(entry.key), isTrue);
        expect(azkarNames.containsKey(entry.key), isTrue);
        expect(
          entry.value
              .map((item) => '${item.count}:${item.data}')
              .toSet()
              .length,
          entry.value.length,
        );
        expect(entry.value.every((item) => item.count > 0), isTrue);
      }
    },
  );

  test(
    'rapid taps stay bounded and the latest count, position and size restore',
    () async {
      final session = AzkarSession('sample', sampleItems());
      await session.load();
      for (var i = 0; i < 20; i++) {
        session.changeCount(1);
      }
      expect(session.countAt(0), 3);
      session.changeCount(-1);
      session.resize(4);
      session.select(1);
      session.changeCount(1);
      await session.saved;
      final restored = AzkarSession('sample', sampleItems());
      await restored.load();
      expect(restored.countAt(0), 2);
      expect(restored.countAt(1), 1);
      expect(restored.index, 1);
      expect(restored.completed, 1);
      expect(restored.fontSize, 32);
      session.dispose();
      restored.dispose();
    },
  );

  test('font and count lower and upper bounds are enforced', () async {
    final session = AzkarSession('sample', sampleItems());
    await session.load();
    session.changeCount(-99);
    session.resize(-100);
    expect(session.countAt(0), 0);
    expect(session.fontSize, AzkarSession.minFontSize);
    session.resize(100);
    expect(session.fontSize, AzkarSession.maxFontSize);
    await session.saved;
    session.dispose();
  });

  test(
    'reset affects only its collection, not text size or other sessions',
    () async {
      final first = AzkarSession('first', sampleItems());
      final second = AzkarSession('second', sampleItems());
      await first.load();
      await second.load();
      first.changeCount(2);
      first.resize(2);
      second.changeCount(1);
      await first.saved;
      await second.saved;
      first.reset();
      await first.saved;
      expect(first.repetitions, 0);
      expect(second.repetitions, 1);
      final restored = AzkarSession('second', sampleItems());
      await restored.load();
      expect(restored.repetitions, 1);
      expect(restored.fontSize, 30);
      first.dispose();
      second.dispose();
      restored.dispose();
    },
  );

  test(
    'reordering restores by content, changed content starts from zero',
    () async {
      final session = AzkarSession('sample', sampleItems());
      await session.load();
      session.changeCount(2);
      await session.saved;
      final reordered = AzkarSession('sample', sampleItems().reversed.toList());
      await reordered.load();
      expect(reordered.index, 1);
      expect(reordered.countAt(1), 2);
      final changed = AzkarSession('sample', [
        AzkarItem(data: 'First corrected', count: 3),
      ]);
      await changed.load();
      expect(changed.repetitions, 0);
      session.dispose();
      reordered.dispose();
      changed.dispose();
    },
  );

  test(
    'malformed storage does not block reading and later writes recover',
    () async {
      SharedPreferences.setMockInitialValues({
        'azkar.session.v1.sample': '{broken',
        AzkarSession.fontKey: -50.0,
      });
      final session = AzkarSession('sample', sampleItems());
      await session.load();
      expect(session.loaded, isTrue);
      expect(session.storageError, isTrue);
      expect(session.fontSize, AzkarSession.minFontSize);
      session.changeCount(1);
      await session.saved;
      expect(session.storageError, isFalse);
      session.dispose();
    },
  );

  test(
    'persisted counter values are clamped and unrelated records ignored',
    () async {
      SharedPreferences.setMockInitialValues({
        'azkar.session.v1.sample': jsonEncode({
          'counts': {'3:First': 999, '1:Second': -1, 'missing': 99},
          'current': 'missing',
        }),
      });
      final session = AzkarSession('sample', sampleItems());
      await session.load();
      expect(session.countAt(0), 3);
      expect(session.countAt(1), 0);
      expect(session.repetitions, 3);
      expect(session.index, 0);
      session.dispose();
    },
  );

  testWidgets('category search supports Arabic and opens the matching reader', (
    tester,
  ) async {
    await tester.pumpWidget(azkarHost(const AzkarPageClass()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('azkar-search')),
      'المساء',
    );
    await tester.pumpAndSettle();
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('Morning'), findsNothing);
    await reveal(tester, find.byKey(const ValueKey('category-Azkar_Night')));
    await tester.tap(find.byKey(const ValueKey('category-Azkar_Night')));
    await tester.pumpAndSettle();
    expect(find.byType(AzkarCardPageClass), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
  });

  testWidgets(
    'counter completes, caps and undoes without advancing automatically',
    (tester) async {
      await tester.pumpWidget(
        azkarHost(const AzkarCardPageClass(keyname: 'Azkar_Wakeup')),
      );
      await tester.pumpAndSettle();
      final count = find.byKey(const ValueKey('azkar-count-button'));
      await reveal(tester, count);
      await tester.tap(count);
      await tester.pumpAndSettle();
      expect(find.text('Repetitions · 1 / 1'), findsOneWidget);
      expect(tester.widget<FilledButton>(count).onPressed, isNull);
      expect(find.text('Dhikr 1 of 3'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('azkar-undo')));
      await tester.tap(find.byKey(const ValueKey('azkar-undo')));
      await tester.pumpAndSettle();
      expect(find.text('Repetitions · 0 / 1'), findsOneWidget);
      expect(tester.widget<FilledButton>(count).onPressed, isNotNull);
    },
  );

  testWidgets(
    'font controls persist, and previous/next preserve independent counts',
    (tester) async {
      await tester.pumpWidget(
        azkarHost(const AzkarCardPageClass(keyname: 'Azkar_Wakeup')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('azkar-font-plus')));
      await tester.pumpAndSettle();
      expect(find.text('30'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('azkar-count-button')));
      await tester.tap(find.byKey(const ValueKey('azkar-count-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('azkar-next')));
      await tester.pumpAndSettle();
      expect(find.text('Dhikr 2 of 3'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('azkar-count')));
      expect(find.text('Repetitions · 0 / 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('azkar-previous')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('azkar-count')));
      expect(find.text('Repetitions · 1 / 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        azkarHost(const AzkarCardPageClass(keyname: 'Azkar_Wakeup')),
      );
      await tester.pumpAndSettle();
      expect(find.text('30'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('azkar-count')));
      expect(find.text('Repetitions · 1 / 1'), findsOneWidget);
    },
  );

  testWidgets('reset requires confirmation, with cancel preserving progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      azkarHost(const AzkarCardPageClass(keyname: 'Azkar_Wakeup')),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('azkar-count-button')));
    await tester.tap(find.byKey(const ValueKey('azkar-count-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('azkar-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep reading'));
    await tester.pumpAndSettle();
    expect(find.text('Repetitions · 1 / 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('azkar-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-azkar-reset')));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('azkar-count')));
    expect(find.text('Repetitions · 0 / 1'), findsOneWidget);
  });

  testWidgets(
    'picker searches Arabic without diacritics and jumps to the result',
    (tester) async {
      await tester.pumpWidget(
        azkarHost(const AzkarCardPageClass(keyname: 'Azkar_Wakeup')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('azkar-browse')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('azkar-reader-search')),
        'جسدي',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('browse-dhikr-0')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('browse-dhikr-1')));
      await tester.pumpAndSettle();
      expect(find.text('Dhikr 2 of 3'), findsOneWidget);
    },
  );

  testWidgets('completion is reversible and the last next button is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      azkarHost(const AzkarCardPageClass(keyname: 'Azkar_Wakeup')),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await reveal(tester, find.byKey(const ValueKey('azkar-count-button')));
      await tester.tap(find.byKey(const ValueKey('azkar-count-button')));
      await tester.pumpAndSettle();
      if (i < 2) {
        await tester.tap(find.byKey(const ValueKey('azkar-next')));
        await tester.pumpAndSettle();
      }
    }
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('azkar-next')))
          .onPressed,
      isNull,
    );
    await reveal(tester, find.byKey(const ValueKey('azkar-undo')));
    await tester.tap(find.byKey(const ValueKey('azkar-undo')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('azkar-complete')), findsNothing);
    expect(find.text('2 of 3 adhkar completed'), findsOneWidget);
  });

  testWidgets('copy sends only the original dhikr text to the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      azkarHost(const AzkarCardPageClass(keyname: 'Azkar_Wakeup')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy dhikr'));
    await tester.pumpAndSettle();
    expect(copied, AzkarCategories['Azkar_Wakeup']!.first.data);
  });

  testWidgets('existing description remains visible and can be folded', (
    tester,
  ) async {
    final session = AzkarSession(
      'Azkar_Morning',
      AzkarCategories['Azkar_Morning']!,
    );
    await session.load();
    session.select(1);
    await session.saved;
    session.dispose();
    await tester.pumpWidget(
      azkarHost(const AzkarCardPageClass(keyname: 'Azkar_Morning')),
    );
    await tester.pumpAndSettle();
    final description = AzkarCategories['Azkar_Morning']![1].description;
    await reveal(tester, find.text(description));
    expect(find.text(description), findsOneWidget);
    await tester.ensureVisible(find.text('About this dhikr'));
    await tester.tap(find.text('About this dhikr'));
    await tester.pumpAndSettle();
    expect(find.text(description), findsNothing);
  });

  testWidgets('invalid category remains readable without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      azkarHost(const AzkarCardPageClass(keyname: 'missing')),
    );
    await tester.pumpAndSettle();
    expect(find.text('This collection is unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'picker and reset retain accessibility scaling with the keyboard open',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // Mirror main.dart's fixed root scale. Each overlay must restore the device scale.
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: child!,
          ),
          home: const AzkarCardPageClass(keyname: 'Azkar_Wakeup'),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('azkar-count-button')));
      await tester.tap(find.byKey(const ValueKey('azkar-count-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('azkar-reset')));
      await tester.pumpAndSettle();
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(AlertDialog)),
        ).scale(10),
        20,
      );
      await tester.tap(find.text('Keep reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('azkar-browse')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 350);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('azkar-reader-search')),
        'جسدي',
      );
      await tester.pumpAndSettle();
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byKey(const ValueKey('azkar-reader-search'))),
        ).scale(10),
        20,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final arabic in [false, true]) {
    testWidgets(
      'small screen large text and dark mode (${arabic ? 'Arabic' : 'English'})',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await tester.pumpWidget(
          azkarHost(const AzkarPageClass(), arabic: arabic),
        );
        await tester.pumpAndSettle();
        await reveal(
          tester,
          find.byKey(const ValueKey('category-Azkar_Morning')),
        );
        await tester.tap(find.byKey(const ValueKey('category-Azkar_Morning')));
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const ValueKey('azkar-count-button')));
        await tester.tap(find.byKey(const ValueKey('azkar-count-button')));
        await tester.pumpAndSettle();
        expect(
          Directionality.of(
            tester.element(find.byKey(const ValueKey('azkar-count-button'))),
          ),
          arabic ? TextDirection.rtl : TextDirection.ltr,
        );
        await tester.tap(find.byKey(const ValueKey('azkar-browse')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
