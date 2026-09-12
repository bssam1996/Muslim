import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muslim/UI/dua/data/dua_preview.dart';
import 'package:muslim/UI/dua/data/dua_repository.dart';
import 'package:muslim/UI/dua/dua_page.dart';
import 'package:muslim/UI/dua/dua_preferences.dart';
import 'package:muslim/UI/dua/dua_reader.dart';
import 'package:muslim/UI/dua/models/dua_catalog.dart';
import 'package:muslim/UI/dua/search/dua_library_search.dart';
import 'package:muslim/UI/dua/widgets/dua_sources.dart';

DuaCatalog pilot() => DuaCatalog.decode(duaPreviewJson, allowPreview: true);
Widget host(Widget child, {bool arabic = false}) => MaterialApp(
  locale: Locale(arabic ? 'ar' : 'en'),
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);
Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('repository exposes source-checked library without an opt-in', (
    tester,
  ) async {
    final catalog = await DuaRepository.load();
    expect(catalog.entries.length, 25);
    expect(catalog.entries.every((entry) => !entry.published), isTrue);
    expect(catalog.entries.any((entry) => entry.id == 'new-garment'), isTrue);
    expect(
      duaShareText(catalog.entries.first, catalog),
      isNot(contains('review pending')),
    );
    await tester.pumpWidget(host(const DuaPageClass()));
    await tester.pumpAndSettle();
    expect(find.byType(DuaLibraryPage), findsOneWidget);
    expect(
      find.text(
        '25 source-checked duaas. Independent editorial review is pending.',
      ),
      findsNothing,
    );
  });
  test('25 source-checked drafts pass schema checks but are not approved', () {
    final c = pilot();
    expect(c.entries.length, 25);
    expect(c.entries.every((e) => !e.published), isTrue);
    expect(c.sourcesFor(c.entries).length, 24);
    expect(() => DuaCatalog.decode(duaPreviewJson), throwsFormatException);
    expect(
      DuaCatalog.decode(
        File('assets/dua/catalog/catalog.json').readAsStringSync(),
      ).entries,
      isEmpty,
    );
    expect(c.entries.map((e) => e.arabic).toSet().length, c.entries.length);
  });
  test(
    'approval is version matched and missing evidence cannot pass review',
    () {
      final json = jsonDecode(duaPreviewJson) as Map<String, dynamic>;
      for (final e in json['entries']) {
        e['review'].addAll({
          'status': 'published',
          'reviewer': 'Test fixture reviewer only',
          'approvedAt': '2026-09-10',
          'textChecked': true,
          'contextChecked': true,
          'countsChecked': true,
          'approvedVersion': 1,
          'languageChecked': true,
          'rightsCleared': true,
        });
      }
      expect(DuaCatalog.decode(jsonEncode(json)).entries.length, 25);
      json['entries'][0]['version'] = 2;
      expect(() => DuaCatalog.decode(jsonEncode(json)), throwsFormatException);
      json['entries'][0]['version'] = 1;
      json['entries'][0]['blocks'][0]['sources'] = ['missing'];
      expect(() => DuaCatalog.decode(jsonEncode(json)), throwsFormatException);
    },
  );
  test(
    'counts are contextual and no instructions are embedded in Travel recitation',
    () {
      final c = pilot();
      final travel = c.entries.singleWhere((e) => e.id == 'travel');
      expect(travel.blocks.first.repeat, 3);
      expect(travel.blocks.last.repeat, isNull);
      expect(travel.arabic, isNot(contains('وكان إذا')));
      expect(travel.arabic, isNot(contains('والولد')));
      expect(
        c.entries
            .singleWhere((e) => e.id == 'pain')
            .blocks
            .map((b) => b.repeat),
        [3, 7],
      );
      expect(
        c.entries
            .singleWhere((e) => e.id == 'new-garment')
            .blocks
            .single
            .repeat,
        isNull,
      );
    },
  );
  final fixtures =
      jsonDecode(File('test/fixtures/duaa_search.json').readAsStringSync())
          as List;
  for (final fixture in fixtures) {
    test('search: ${fixture['query']}', () {
      final result = DuaLibrarySearch(pilot()).search(fixture['query']);
      expect(
        result.entries.take(3).map((e) => e.id),
        contains(fixture['expected']),
      );
    });
  }
  test(
    'unsupported purchases do not get a new-garment ritual; filters remain strict',
    () {
      final engine = DuaLibrarySearch(pilot());
      for (final query in ['new phone', 'new house', 'new car']) {
        expect(
          engine.search(query).entries.map((e) => e.id),
          isNot(contains('new-garment')),
        );
      }
      expect(engine.search('new phone', category: 'travel').entries, isEmpty);
      expect(
        engine.search('new clothes', grade: 'quran').entries.map((e) => e.id),
        ['gratitude'],
      );
      expect(
        engine.search('', tags: {'new', 'rain'}).entries.map((e) => e.id),
        containsAll(['new-garment', 'rain']),
      );
      expect(engine.search('', onlyIds: {}).entries, isEmpty);
      expect(engine.search('unknownzzzz').entries, isEmpty);
      expect(engine.search('cannot sleep').destination, 'azkar');
      expect(engine.search('cannot sleep').entries, isEmpty);
      expect(engine.search('hajj').destination, 'hajj');
      expect(engine.search('umrah').destination, 'umrah');
    },
  );
  test('normalization and typo suggestions never rewrite original Arabic', () {
    expect(normalizeDua('مُسْلِم ١٣٤٢'), 'مسلم 1342');
    final engine = DuaLibrarySearch(pilot());
    expect(engine.search('traveel').suggestion, 'travel');
    expect(engine.search('traveel').entries, isEmpty);
    expect(
      engine.search('اللَّهُمَّ').entries.map((e) => e.id),
      engine.search('اللهم').entries.map((e) => e.id),
    );
  });

  test('500-entry search benchmark and stable ranking', () {
    final json = jsonDecode(duaPreviewJson) as Map<String, dynamic>;
    final originals = json['entries'] as List;
    json['entries'] = [
      for (var i = 0; i < 500; i++)
        {
          ...originals[i % originals.length] as Map<String, dynamic>,
          'id': 'benchmark-$i',
          'related': <String>[],
        },
    ];
    json['redirects'] = <String, String>{};
    final engine = DuaLibrarySearch(
      DuaCatalog.decode(jsonEncode(json), allowPreview: true),
    );
    final clock = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      engine.search('اللهم');
    }
    clock.stop();
    // Development-host guard only, not a claim about a physical phone.
    expect(clock.elapsedMilliseconds / 100, lessThan(100));
    expect(
      engine.search('اللهم').entries.map((e) => e.id),
      engine.search('اللهم').entries.map((e) => e.id),
    );
  });

  testWidgets('source shortcut reaches the footer of a long reader', (
    tester,
  ) async {
    final c = pilot(), prefs = DuaPreferences(pilot());
    await prefs.load();
    addTearDown(prefs.dispose);
    await tester.pumpWidget(
      host(
        DuaReader(
          entry: c.entries.singleWhere((e) => e.id == 'istikhara'),
          catalog: c,
          preferences: prefs,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('duaa-jump-sources')));
    await tester.pumpAndSettle();
    expect(find.text('Sources and verification').hitTestable(), findsOneWidget);
  });
  test(
    'favourites/recent migration, limits and preferences survive reopening',
    () async {
      SharedPreferences.setMockInitialValues({
        'duaa.favourites': ['Dua_Travel', 'removed'],
        'duaa.recent': ['removed', 'travel'],
        'duaa.font': 999.0,
      });
      final prefs = DuaPreferences(pilot());
      await prefs.load();
      expect(prefs.favourites, {'travel'});
      expect(prefs.recent, ['travel']);
      expect(prefs.fontSize, 40);
      prefs.resize(-99);
      expect(prefs.fontSize, 20);
      prefs.resetFont();
      prefs.toggle('gratitude');
      for (final e in prefs.catalog.entries) {
        prefs.opened(e.id);
      }
      await prefs.saved;
      expect(prefs.recent.length, 20);
      final restored = DuaPreferences(pilot());
      await restored.load();
      expect(restored.favourites, {'travel', 'gratitude'});
      expect(restored.fontSize, 28);
      restored.clearRecent();
      await restored.saved;
      expect(restored.recent, isEmpty);
      prefs.dispose();
      restored.dispose();
    },
  );
  test(
    'export has citations and optional meaning but no usage instructions',
    () {
      final c = pilot(),
          e = pilot().entries.singleWhere((e) => e.id == 'travel');
      final shared = duaShareText(e, c);
      expect(shared, contains('https://sunnah.com/muslim:1342'));
      expect(shared, isNot(contains('review pending')));
      expect(shared, isNot(contains(e.guidance.en)));
      expect(shared, isNot(contains(e.blocks.last.meaning)));
      expect(
        duaShareText(e, c, meaning: true),
        contains(e.blocks.last.meaning),
      );
    },
  );
  testWidgets(
    'library search opens correct reader and preserves query on return',
    (tester) async {
      await tester.pumpWidget(host(DuaLibraryPage(catalog: pilot())));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('duaa-search')),
        'new shirt',
      );
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('duaa-entry-new-garment')),
      );
      await tester.tap(find.byKey(const ValueKey('duaa-entry-new-garment')));
      await tester.pumpAndSettle();
      expect(find.byType(DuaReader), findsOneWidget);
      expect(
        find.textContaining('independent review of wording'),
        findsNothing,
      );
      expect(find.text('Check sources'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('duaa-bookmark')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('duaa-search')),
        -300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('duaa-search')))
            .controller!
            .text,
        'new shirt',
      );
    },
  );
  testWidgets('phone results carry limitation and omit garment entry', (
    tester,
  ) async {
    await tester.pumpWidget(host(DuaLibraryPage(catalog: pilot())));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('duaa-search')),
      'new phone',
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.textContaining('We have not verified'));
    expect(find.byKey(const ValueKey('duaa-entry-new-garment')), findsNothing);
    expect(find.text('Vehicle'), findsOneWidget);
  });
  testWidgets('per-block counts stay separate and undo works', (tester) async {
    final c = pilot(), prefs = DuaPreferences(pilot());
    await prefs.load();
    addTearDown(prefs.dispose);
    await tester.pumpWidget(
      host(
        DuaReader(
          entry: c.entries.singleWhere((e) => e.id == 'pain'),
          catalog: c,
          preferences: prefs,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey('count-button-bismillah'));
    await reveal(tester, first);
    for (var i = 0; i < 3; i++) {
      await tester.tap(first);
      await tester.pumpAndSettle();
    }
    expect(tester.widget<FilledButton>(first).onPressed, isNull);
    await reveal(tester, find.byKey(const ValueKey('undo-bismillah')));
    await tester.tap(find.byKey(const ValueKey('undo-bismillah')));
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('count-text')));
    expect(find.text('0 of 7'), findsOneWidget);
  });
  testWidgets(
    'source launcher failure retains readable citation and browser retry',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final source = pilot().sources['m:1342']!;
      await tester.pumpWidget(
        host(Scaffold(body: DuaSourceReader(source: source))),
      );
      await tester.tap(find.text('Read source'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open the source.'), findsOneWidget);
      expect(find.text(source.url), findsOneWidget);
      expect(find.text('Open in browser'), findsOneWidget);
    },
  );
  for (final arabic in [false, true]) {
    testWidgets(
      'narrow dark enlarged reader and filters ${arabic ? 'Arabic' : 'English'}',
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
          host(DuaLibraryPage(catalog: pilot()), arabic: arabic),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('duaa-search')),
          'new shirt',
        );
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const ValueKey('duaa-filters')));
        await tester.tap(find.byKey(const ValueKey('duaa-filters')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('filter-sahih')));
        await tester.pumpAndSettle();
        Navigator.of(
          tester.element(find.byKey(const ValueKey('filter-sahih'))),
        ).pop();
        await tester.pumpAndSettle();
        await reveal(
          tester,
          find.byKey(const ValueKey('duaa-entry-new-garment')),
        );
        await tester.tap(find.byKey(const ValueKey('duaa-entry-new-garment')));
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const ValueKey('recitation-text')));
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).first)
              .textDirection,
          TextDirection.rtl,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
