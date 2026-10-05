import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/shared/home_action_grid.dart';
import 'package:muslim/shared/responsive_web_layout.dart';
import 'package:muslim/shared/web_home_style.dart';

void main() {
  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  for (final width in [390.0, 800.0, 1440.0, 2560.0]) {
    testWidgets('web routes and MediaQuery fit a $width pixel window', (
      tester,
    ) async {
      await setSize(tester, Size(width, 900));
      Size? routeSize;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ResponsiveWebViewport(child: child!),
          home: Builder(
            builder: (context) {
              routeSize = MediaQuery.sizeOf(context);
              return Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const Scaffold(
                        body: Center(child: Text('Next page')),
                      ),
                    ),
                  ),
                  child: const Text('Open page'),
                ),
              );
            },
          ),
        ),
      );
      final expectedWidth = width > 1120 ? 1120.0 : width;
      expect(routeSize, Size(expectedWidth, 900));
      expect(tester.getSize(find.byType(Scaffold)).width, expectedWidth);
      expect(
        tester.getTopLeft(find.byType(Scaffold)).dx,
        (width - expectedWidth) / 2,
      );
      await tester.tap(find.text('Open page'));
      await tester.pumpAndSettle();
      expect(find.text('Next page'), findsOneWidget);
      expect(tester.getSize(find.byType(Scaffold)).width, expectedWidth);
      expect(tester.takeException(), isNull);
    });
  }

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    for (final width in [390.0, 800.0, 1120.0]) {
      testWidgets('dashboard adapts at $width pixels in $direction', (
        tester,
      ) async {
        await setSize(tester, Size(width, 900));
        const prayerKey = ValueKey('prayers');
        const contentKey = ValueKey('content');
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: const SingleChildScrollView(
                child: HomeDashboardLayout(
                  allowWideLayout: true,
                  prayerPanel: SizedBox(key: prayerKey, height: 400),
                  contentPanel: SizedBox(key: contentKey, height: 300),
                ),
              ),
            ),
          ),
        );
        final prayer = tester.getRect(find.byKey(prayerKey));
        final content = tester.getRect(find.byKey(contentKey));
        if (width >= 960) {
          expect(prayer.top, content.top);
          expect(prayer.bottom, content.bottom);
          expect(prayer.width, 420);
          if (direction == TextDirection.ltr) {
            expect(content.left - prayer.right, 24);
          } else {
            expect(prayer.left - content.right, 24);
          }
        } else {
          expect(content.top, prayer.bottom);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('native dashboard remains stacked on a wide screen', (
    tester,
  ) async {
    await setSize(tester, const Size(1120, 900));
    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(
          child: HomeDashboardLayout(
            allowWideLayout: false,
            prayerPanel: SizedBox(key: ValueKey('prayers'), height: 400),
            contentPanel: SizedBox(key: ValueKey('content'), height: 300),
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const ValueKey('content'))).dy, 400);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prayer pager stretches to match growing shortcut content', (
    tester,
  ) async {
    await setSize(tester, const Size(1120, 1000));
    final pageController = PageController();
    addTearDown(pageController.dispose);
    for (final hadithHeight in [200.0, 480.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: HomeDashboardLayout(
              allowWideLayout: true,
              prayerPanel: WebPrayerPanel(
                key: const ValueKey('prayer_panel'),
                styled: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pager = PageView(
                      controller: pageController,
                      children: const [
                        Center(child: Text('Prayer times')),
                        Center(child: Text('Tomorrow')),
                      ],
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        Flexible(
                          fit: constraints.hasBoundedHeight
                              ? FlexFit.tight
                              : FlexFit.loose,
                          child: SizedBox(
                            height: constraints.hasBoundedHeight ? null : 300,
                            child: pager,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              contentPanel: Column(
                key: const ValueKey('shortcut_panel'),
                children: [
                  SizedBox(height: hadithHeight),
                  HomeActionGrid(
                    compact: true,
                    maxColumns: 2,
                    children: List.generate(
                      6,
                      (index) => SizedBox(key: ValueKey('shortcut_$index')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final prayer = tester.getRect(find.byKey(const ValueKey('prayer_panel')));
      final shortcuts = tester.getRect(
        find.byKey(const ValueKey('shortcut_panel')),
      );
      final lastShortcut = tester.getRect(
        find.byKey(const ValueKey('shortcut_5')),
      );
      expect(prayer.top, shortcuts.top);
      expect(prayer.bottom, lastShortcut.bottom);
      expect(prayer.height, greaterThan(500));
      if (hadithHeight == 200) {
        pageController.jumpToPage(1);
        await tester.pumpAndSettle();
      }
      expect(pageController.page, 1);
      expect(tester.takeException(), isNull);
    }
  });

  for (final width in [320.0, 390.0, 600.0, 800.0, 1088.0]) {
    for (final arabic in [false, true]) {
      testWidgets(
        'action tiles fit and remain usable at $width, Arabic: $arabic',
        (tester) async {
          await setSize(tester, Size(width, 900));
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: HomeActionGrid(
                        compact: width >= 600,
                        children: [
                          for (var i = 0; i < 4; i++)
                            HomeActionTile(
                              key: ValueKey('tile_$i'),
                              styled: width >= 600,
                              icon: Icons.mosque_outlined,
                              title: arabic
                                  ? 'البحث عن أقرب مسجد'
                                  : 'Find the nearest mosque',
                              assetPath: 'assets/mosque/mosque_home.png',
                              onTap: () => taps++,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final tile = find.byKey(const ValueKey('tile_0'));
          final tileSize = tester.getSize(tile);
          if (width >= 600) {
            expect(tileSize.height, 112);
            expect(tileSize.width, lessThan(300));
          } else {
            expect(tileSize.width / tileSize.height, closeTo(1.45, .001));
          }
          await tester.tap(tile);
          await tester.pump();
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
