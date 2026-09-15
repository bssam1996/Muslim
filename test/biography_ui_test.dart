import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/biographies/biography_catalog.dart';
import 'package:muslim/UI/biographies/biography_page.dart';
import 'package:muslim/UI/biographies/book_reader_page.dart';
import 'package:muslim/UI/biographies/storage/book_storage.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStorage implements BookStorage {
  final saved = {biographyAuthors.single.books.first.id};
  bool failDelete = false;
  Completer<void>? deletion;

  @override
  Future<bool> contains(String id) async => saved.contains(id);
  @override
  Future<void> delete(String id) async {
    if (deletion != null) await deletion!.future;
    if (failDelete) throw StateError('Storage unavailable');
    saved.remove(id);
  }

  @override
  Future<StoredBook> read(String id) => throw UnimplementedError();
  @override
  Future<void> save(
    String id,
    Stream<List<int>> bytes,
    BookValidator validate,
  ) => throw UnimplementedError();
}

class _Host extends StatelessWidget {
  const _Host(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: context.locale,
    localizationsDelegates: context.localizationDelegates,
    supportedLocales: context.supportedLocales,
    home: child,
  );
}

class _TestLoader extends AssetLoader {
  const _TestLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(
            File(
              '$path/${locale.languageCode}-${locale.countryCode}.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    final arabic = locale.languageCode == 'ar';
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      bool settle = true,
    }) async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
          startLocale: locale,
          saveLocale: false,
          path: 'assets/translations',
          assetLoader: const _TestLoader(),
          child: _Host(child),
        ),
      );
      if (settle) await tester.pumpAndSettle();
    }

    testWidgets(
      'bookmarks survive reopening and navigate to the saved PDF page: $locale',
      (tester) async {
        Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
        await tester.runAsync(() => pdfrxFlutterInitialize());
        final author = biographyAuthors.single;
        final book = author.books.last;
        final stored = StoredBook.file(
          File(
            'Books/Prophet Muhammed Biography/${book.directory}/${book.fileName}',
          ).absolute.path,
        );
        Future<PdfViewerController> openReader() async {
          await pump(
            tester,
            BookReaderPage(book: book, author: author, stored: stored),
            settle: false,
          );
          for (var i = 0; i < 200; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 20));
            final viewer = find.byType(PdfViewer);
            if (viewer.evaluate().isNotEmpty) {
              final controller = tester.widget<PdfViewer>(viewer).controller!;
              if (controller.isReady &&
                  find
                      .byTooltip('Biography_Next_Page'.tr())
                      .evaluate()
                      .isNotEmpty) {
                return controller;
              }
            }
          }
          throw StateError('PDF reader did not become ready');
        }

        var controller = await openReader();
        await controller.goToPage(pageNumber: 3, duration: Duration.zero);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Biography_Add_Bookmark'.tr()));
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Biography_Remove_Bookmark'.tr()),
          findsOneWidget,
        );

        await controller.goToPage(pageNumber: 1, duration: Duration.zero);
        await tester.pumpAndSettle();
        // Close and reopen the same book, retaining the saved bookmark on page 3.
        await tester.pumpWidget(const SizedBox.shrink());
        controller = await openReader();
        await tester.tap(find.byTooltip('Biography_Bookmarks'.tr()));
        await tester.pumpAndSettle();
        final bookmark = find.text(
          'Biography_Bookmark_Page'.tr(namedArgs: {'page': '3'}),
        );
        expect(bookmark, findsOneWidget);
        await tester.tap(bookmark);
        await tester.pumpAndSettle();
        expect(controller.pageNumber, 3);

        await tester.tap(find.byTooltip('Biography_Remove_Bookmark'.tr()));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await openReader();
        await tester.tap(find.byTooltip('Biography_Bookmarks'.tr()));
        await tester.pumpAndSettle();
        expect(find.text('Biography_No_Bookmarks'.tr()), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        // The PDF viewer polls for its initial render every 100 ms. Allow its
        // final poll to observe disposal before the test checks pending timers.
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'author selection is translated and follows reading direction: $locale',
      (tester) async {
        await pump(tester, const BiographyPage());
        expect(
          find.text(arabic ? 'السيرة النبوية' : 'Prophet Muhammed Biography'),
          findsOneWidget,
        );
        final author = find.text(arabic ? 'ابن كثير' : 'Ibn Kathir');
        expect(author, findsOneWidget);
        expect(
          Directionality.of(tester.element(author)).name,
          arabic ? 'rtl' : 'ltr',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'book choices show read/update for saved books and download for new books: $locale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pump(
          tester,
          BiographyBooksPage(
            author: biographyAuthors.single,
            storage: _MemoryStorage(),
          ),
        );
        expect(
          find.text(arabic ? 'الكتاب الكامل' : 'Full book'),
          findsOneWidget,
        );
        expect(find.text(arabic ? 'الملخص' : 'Summary'), findsOneWidget);
        expect(find.text(arabic ? 'قراءة' : 'Read'), findsOneWidget);
        expect(
          find.text(arabic ? 'إعادة التنزيل' : 'Re-download'),
          findsOneWidget,
        );
        expect(find.text(arabic ? 'تنزيل' : 'Download'), findsOneWidget);
        expect(
          find.text(arabic ? 'حذف التنزيل' : 'Delete download'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('deleting a book restores its download option: $locale', (
      tester,
    ) async {
      final storage = _MemoryStorage()..deletion = Completer<void>();
      await pump(
        tester,
        BiographyBooksPage(author: biographyAuthors.single, storage: storage),
      );
      await tester.tap(find.text('Biography_Delete_Download'.tr()));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Biography_Delete_Download'.tr()),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Biography_Read'.tr()), findsOneWidget);
      storage.deletion!.complete();
      await tester.pumpAndSettle();
      expect(storage.saved, isEmpty);
      expect(find.text('Biography_Read'.tr()), findsNothing);
      expect(find.text('Biography_Delete_Download'.tr()), findsNothing);
      expect(find.text('Biography_Download'.tr()), findsNWidgets(2));
      expect(find.text('Biography_Delete_Complete'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'failed deletion keeps the book available and allows retry: $locale',
      (tester) async {
        final storage = _MemoryStorage()..failDelete = true;
        await pump(
          tester,
          BiographyBooksPage(author: biographyAuthors.single, storage: storage),
        );
        await tester.tap(find.text('Biography_Delete_Download'.tr()));
        await tester.pumpAndSettle();
        expect(storage.saved, isNotEmpty);
        expect(find.text('Biography_Read'.tr()), findsOneWidget);
        expect(find.text('Biography_Delete_Error'.tr()), findsOneWidget);
        expect(find.text('Biography_Delete_Complete'.tr()), findsNothing);
        storage.failDelete = false;
        await tester.tap(find.text('Biography_Delete_Download'.tr()));
        await tester.pumpAndSettle();
        expect(storage.saved, isEmpty);
        expect(find.text('Biography_Delete_Error'.tr()), findsNothing);
        expect(find.text('Biography_Download'.tr()), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'all biography UI keys exist in both translations with matching placeholders',
    () {
      final en =
          jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
              as Map<String, dynamic>;
      final ar =
          jsonDecode(File('assets/translations/ar-EG.json').readAsStringSync())
              as Map<String, dynamic>;
      final pattern = RegExp(r"'((?:Biography_)[A-Za-z_]+)'");
      final placeholders = RegExp(r'\{[^}]+\}');
      for (final file in Directory(
        'lib/UI/biographies',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        for (final match in pattern.allMatches(file.readAsStringSync())) {
          final key = match[1]!;
          expect(en[key], isA<String>(), reason: key);
          expect(ar[key], isA<String>(), reason: key);
          expect(
            placeholders.allMatches(en[key] as String).map((m) => m[0]).toSet(),
            placeholders.allMatches(ar[key] as String).map((m) => m[0]).toSet(),
            reason: key,
          );
        }
      }
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains(biographyIcon));
      expect(pubspec, isNot(contains('    - "Books/')));
      expect(pubspec, isNot(contains('.pdf')));
    },
  );
}
