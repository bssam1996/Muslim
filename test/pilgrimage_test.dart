import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muslim/UI/dua/dua_search.dart';
import 'package:muslim/UI/dua/dua_page.dart';
import 'package:muslim/UI/home/pilgrimage_menu_entries.dart';
import 'package:muslim/UI/dua/pilgrimage/pilgrimage_content.dart';
import 'package:muslim/UI/dua/pilgrimage/pilgrimage_journey_page.dart';
import 'package:muslim/UI/dua/pilgrimage/pilgrimage_models.dart';
import 'package:muslim/UI/dua/pilgrimage/pilgrimage_routes.dart';
import 'package:muslim/UI/dua/pilgrimage/pilgrimage_sources.dart';

Widget host(Widget child, {bool arabic = false}) => MaterialApp(
  locale: arabic ? const Locale('ar') : const Locale('en'),
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    350,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'every route has unique steps, complete bilingual content and references',
    () {
      for (final route in [umrahRoute(), ...HajjType.values.map(hajjRoute)]) {
        expect(route.map((s) => s.id).toSet().length, route.length);
        for (final step in route) {
          expect(step.title.ar, isNotEmpty);
          expect(step.title.en, isNotEmpty);
          expect(step.content, isNotEmpty);
          for (final content in step.content) {
            expect(content.sources, isNotEmpty, reason: content.id);
            expect(content.guidance.ar, isNotEmpty);
            expect(content.guidance.en, isNotEmpty);
            if (content.kind == ContentKind.instruction) {
              expect(content.action?.en, isNotEmpty, reason: content.id);
              expect(content.action?.ar, isNotEmpty, reason: content.id);
            }
            if (content.kind == ContentKind.riteDhikr) {
              expect(content.arabic, isNotEmpty);
              expect(content.meaning, isNotEmpty);
            }
            for (final source in content.sources) {
              expect(source.status.en, isNotEmpty);
              expect(source.status.ar, isNotEmpty);
              expect(Uri.parse(source.url).scheme, 'https');
            }
          }
        }
        final sources = sourcesForSteps(route);
        expect(sources.map((s) => s.id).toSet().length, sources.length);
      }
    },
  );

  test(
    'Tamattu adds completion and renewed ihram; Qiran/Ifrad avoid a second obligatory Sai',
    () {
      final tamattu = hajjRoute(HajjType.tamattu);
      expect(
        tamattu.map((s) => s.id),
        containsAllInOrder([
          'arrival_sai',
          'umrah_hair',
          'hajj_ihram',
          'mina',
          'arafah',
          'muzdalifah',
          'aqabah',
          'hajj_sai',
          'tashriq',
          'farewell',
        ]),
      );
      for (final type in [HajjType.qiran, HajjType.ifrad]) {
        final route = hajjRoute(type);
        expect(route.map((s) => s.id), isNot(contains('umrah_hair')));
        expect(route.map((s) => s.id), isNot(contains('hajj_ihram')));
        expect(
          route.singleWhere((s) => s.id == 'hajj_sai').condition!.en,
          contains('only if'),
        );
      }
      expect(
        hajjRoute(
          HajjType.ifrad,
        ).singleWhere((s) => s.id == 'hady').condition!.en,
        contains('Not due solely'),
      );
    },
  );

  test('shared texts, exact ramy count and honest attribution', () {
    final umrah = umrahRoute();
    final hajj = hajjRoute(HajjType.tamattu);
    expect(
      identical(umrah.first.content.first, hajj.first.content.first),
      isTrue,
    );
    expect(aqabah.arabic, 'اللَّهُ أَكْبَرُ');
    expect(aqabah.guidance.en, contains('one takbir with each pebble'));
    expect(jamarat.guidance.en, contains('first and middle'));
    expect(jamarat.guidance.en, contains('Do not stop'));
    expect(generalTahlil.kind, ContentKind.generalDua);
    expect(acceptance.kind, ContentKind.generalDua);
    expect(acceptance.guidance.en, contains('not the exact quotation'));
    expect(arafahReportSource.status.en, contains('daʿif'));
  });

  test('Arabic and English searches reach the same rite', () {
    final step = hajjRoute(
      HajjType.overview,
    ).singleWhere((s) => s.id == 'muzdalifah');
    expect(DuaSearch.matches('المزدلفة', step.searchTerms), isTrue);
    expect(DuaSearch.matches('Muzdalifah', step.searchTerms), isTrue);
  });

  testWidgets(
    'step four opens matching guidance, next/previous and source index',
    (tester) async {
      await tester.pumpWidget(host(const PilgrimageJourneyPage(hajj: false)));
      await tester.pumpAndSettle();
      final step = find.byKey(const ValueKey('step-umrah_hair'));
      await reveal(tester, step);
      await tester.tap(step);
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 4'), findsOneWidget);
      expect(find.text('What to do'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('next-step')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('next-step')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('previous-step')));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(find.text('Approaching Safa for the first time'), findsOneWidget);
      await reveal(tester, find.text('Sources and verification'));
      expect(find.text('Sources and verification'), findsOneWidget);
    },
  );

  testWidgets('choice persists and list search opens the same content', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PilgrimageJourneyPage(hajj: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hajj-ifrad')));
    await tester.tap(find.byKey(const ValueKey('list-view')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pilgrimage.hajj.type'), 'ifrad');
    expect(prefs.getBool('pilgrimage.hajj.journey'), isFalse);
    await tester.enterText(
      find.byKey(const ValueKey('journey-search')),
      'جمرة العقبة',
    );
    await tester.pumpAndSettle();
    final step = find.byKey(const ValueKey('step-aqabah'));
    await reveal(tester, step);
    await tester.tap(step);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Takbir with each pebble'));
    expect(find.text(aqabah.guidance.en), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(const PilgrimageJourneyPage(hajj: true)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('hajj-ifrad')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('list-view')))
          .selected,
      isTrue,
    );
  });

  testWidgets('Duaa no longer contains Umrah or Hajj', (tester) async {
    await tester.pumpWidget(host(const DuaPageClass()));
    await tester.pumpAndSettle();
    expect(find.text('Dua_Hajj'), findsNothing);
    expect(find.text('Dua_Umrah'), findsNothing);
    expect(find.byType(DuaLibraryPage), findsOneWidget);
  });

  for (final hajj in [false, true]) {
    testWidgets(
      'Home ${hajj ? "Hajj" : "Umrah"} opens the matching journey and icon',
      (tester) async {
        await tester.pumpWidget(
          host(const Scaffold(body: PilgrimageMenuEntries())),
        );
        await tester.pumpAndSettle();
        final tile = find.byKey(ValueKey(hajj ? 'home-hajj' : 'home-umrah'));
        final icon = tester.widget<Image>(
          find.descendant(of: tile, matching: find.byType(Image)),
        );
        expect(
          (icon.image as AssetImage).assetName,
          hajj ? 'assets/hajj/hajj.png' : 'assets/umrah/main.png',
        );
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PilgrimageJourneyPage>(find.byType(PilgrimageJourneyPage))
              .hajj,
          hajj,
        );
        expect(
          find.text(
            hajj ? 'Your Hajj, step by step' : 'Your Umrah, step by step',
          ),
          findsOneWidget,
        );
        if (hajj) {
          expect(
            tester
                .widget<ChoiceChip>(find.byKey(const ValueKey('hajj-ifrad')))
                .selected,
            isTrue,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final storedType in ['invalid', 'qiran', 'tamattu']) {
    testWidgets('Hajj restores $storedType with Ifrad fallback', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'pilgrimage.hajj.type': storedType,
      });
      await tester.pumpWidget(host(const PilgrimageJourneyPage(hajj: true)));
      await tester.pumpAndSettle();
      final expected = storedType == 'invalid' ? 'ifrad' : storedType;
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(ValueKey('hajj-$expected')))
            .selected,
        isTrue,
      );
    });
  }

  for (final arabic in [false, true]) {
    testWidgets(
      'Tawaf makes two rakahs visible immediately (${arabic ? "Arabic" : "English"})',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          host(
            PilgrimageStyle(
              child: JourneyStepDetails(steps: umrahRoute(), initialIndex: 1),
            ),
            arabic: arabic,
          ),
        );
        await tester.pumpAndSettle();
        final summary = find.byKey(
          const ValueKey('action-summary-after_tawaf'),
        );
        final action = find.descendant(
          of: summary,
          matching: find.text(afterTawaf.action!.resolve(arabic)),
        );
        expect(action.hitTestable(), findsOneWidget);
        await reveal(tester, find.byKey(const ValueKey('content-after_tawaf')));
        expect(
          find.text(arabic ? 'ما عليك فعله' : 'What to do'),
          findsOneWidget,
        );
        expect(find.text(afterTawaf.guidance.resolve(arabic)), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('next visits every Hajj checkpoint and finishes at farewell', (
    tester,
  ) async {
    final steps = hajjRoute(HajjType.tamattu);
    await tester.pumpWidget(
      host(
        PilgrimageStyle(
          child: JourneyStepDetails(steps: steps, initialIndex: 0),
        ),
      ),
    );
    for (var i = 0; i < steps.length; i++) {
      await tester.pumpAndSettle();
      expect(find.text('Step ${i + 1} of ${steps.length}'), findsOneWidget);
      expect(find.text(steps[i].stage.en), findsWidgets);
      await reveal(tester, find.byKey(const ValueKey('next-step')));
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('next-step')),
      );
      if (i == steps.length - 1) {
        expect(button.onPressed, isNull);
        expect(steps[i].id, 'farewell');
      } else {
        expect(button.onPressed, isNotNull);
        await tester.tap(find.byKey(const ValueKey('next-step')));
      }
    }
  });

  testWidgets('source sheet keeps citation and offers both browser choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Scaffold(
          body: SourceCitation(source: cornersSource, expanded: true),
        ),
      ),
    );
    await tester.tap(find.text(cornersSource.title.en));
    await tester.pumpAndSettle();
    expect(find.text(cornersSource.url), findsOneWidget);
    expect(find.text('Read source'), findsOneWidget);
    expect(find.text('Open in browser'), findsOneWidget);
    expect(find.text(cornersSource.status.en), findsNWidgets(2));
  });

  testWidgets('offline source failure keeps the reference readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const Scaffold(body: SourceReader(source: cornersSource))),
    );
    await http.runWithClient(() async {
      await tester.tap(find.text('Read source'));
      await tester.pumpAndSettle();
    }, () => MockClient((_) async => throw http.ClientException('offline')));
    expect(find.textContaining('Could not open the source.'), findsOneWidget);
    expect(find.text(cornersSource.url), findsOneWidget);
    expect(find.text(cornersSource.title.en), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'source link opens the exact reference and browser failures are recoverable',
    (tester) async {
      final calls = <MethodCall>[];
      var launchSucceeds = true;
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return launchSucceeds;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        host(const Scaffold(body: SourceReader(source: cornersSource))),
      );
      await http.runWithClient(() async {
        await tester.tap(find.text('Open in browser'));
        await tester.pumpAndSettle();
        expect(
          calls.singleWhere((c) => c.method == 'launch').arguments['url'],
          cornersSource.url,
        );
        launchSucceeds = false;
        await tester.tap(find.text('Read source'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Could not open the source.'),
          findsOneWidget,
        );
      }, () => MockClient((_) async => http.Response('', 200)));
    },
  );

  testWidgets(
    'Hajj type controls and sources work in dark mode with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(host(const PilgrimageJourneyPage(hajj: true)));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('hajj-qiran')));
      await tester.tap(find.byKey(const ValueKey('hajj-qiran')));
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('hajj-qiran'))),
        ).brightness,
        Brightness.dark,
      );
      await reveal(tester, find.byKey(const ValueKey('step-ihram')));
      await tester.tap(find.byKey(const ValueKey('step-ihram')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Sources and verification'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Arabic small screen at large text scale is RTL and tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const PilgrimageJourneyPage(hajj: false), arabic: true),
    );
    await tester.pumpAndSettle();
    final step = find.byKey(const ValueKey('step-ihram'));
    await reveal(tester, step);
    expect(Directionality.of(tester.element(step)), TextDirection.rtl);
    expect(
      find.bySemanticsLabel(
        'الخطوة 1 من 4: الإحرام والتلبية. فتح الدعاء والإرشادات.',
      ),
      findsOneWidget,
    );
    await tester.tap(step);
    await tester.pumpAndSettle();
    await reveal(tester, find.text(talbiyah.arabic));
    expect(
      tester.widget<EditableText>(find.text(talbiyah.arabic)).textDirection,
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
