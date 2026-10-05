import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim/UI/biographies/storage/book_storage.dart';
import 'package:muslim/UI/books/book_download.dart';
import 'package:muslim/UI/books/book_reader_page.dart';
import 'package:muslim/UI/books/library_book.dart';
import 'package:muslim/UI/books/library_books_page.dart';
import 'package:muslim/UI/prophets/prophet_books_page.dart';
import 'package:muslim/UI/prophets/prophet_catalog.dart';
import 'package:muslim/UI/prophets/prophets_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfrx/pdfrx.dart';

class _Storage implements BookStorage {
  final Map<String, StoredBook> saved = {};
  @override
  Future<bool> contains(String id) async => saved.containsKey(id);
  @override
  Future<StoredBook> read(String id) async => saved[id]!;
  @override
  Future<void> delete(String id) async {
    saved.remove(id);
  }

  @override
  Future<void> save(
    String id,
    Stream<List<int>> bytes,
    BookValidator validate,
  ) async {
    final data = await bytes.expand((chunk) => chunk).toList();
    final book = StoredBook.memory(Uint8List.fromList(data));
    await validate(book);
    saved[id] = book;
  }
}

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(
            File(
              '$path/${locale.languageCode}-${locale.countryCode}.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
}

class _Host extends StatelessWidget {
  const _Host(this.child, this.scale);
  final Widget child;
  final double scale;
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: context.locale,
    supportedLocales: context.supportedLocales,
    localizationsDelegates: context.localizationDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Locale locale, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
      startLocale: locale,
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _Loader(),
      child: _Host(child, scale),
    ),
  );
  await tester.pumpAndSettle();
}

const _languageTestSlots = [
  LibraryBookSlot(
    titleKey: 'Prophets_Kids_Story',
    editions: [
      LibraryBook(
        id: 'prophet_ismail_kids_ar',
        titleKey: 'Prophets_Kids_Story',
        language: 'ar',
        approximateBytes: 50,
        downloadUrl: 'https://example.com/ar/kids.pdf',
      ),
      LibraryBook(
        id: 'prophet_ismail_kids_en',
        titleKey: 'Prophets_Kids_Story',
        language: 'en',
        approximateBytes: 50,
        downloadUrl: 'https://example.com/en/kids.pdf',
      ),
    ],
  ),
  LibraryBookSlot(
    titleKey: 'Prophets_Full_Story',
    editions: [
      LibraryBook(
        id: 'prophet_ismail_full_ar',
        titleKey: 'Prophets_Full_Story',
        language: 'ar',
        approximateBytes: 50,
        downloadUrl: 'https://example.com/ar/full.pdf',
      ),
      LibraryBook(
        id: 'prophet_ismail_full_en',
        titleKey: 'Prophets_Full_Story',
        language: 'en',
        approximateBytes: 50,
        downloadUrl: 'https://example.com/en/full.pdf',
      ),
    ],
  ),
];

Finder _languagePicker(String titleKey) =>
    find.byKey(ValueKey('book_language_$titleKey'));

Future<void> _chooseLanguage(
  WidgetTester tester,
  String titleKey,
  String language,
) async {
  final picker = _languagePicker(titleKey);
  await tester.scrollUntilVisible(
    picker,
    titleKey == 'Prophets_Kids_Story' ? -200 : 200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Books_Language_$language'.tr()).last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    testWidgets(
      'both PDF languages download independently of app language: $locale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = _Storage();
        final requests = <String>[];
        await _pump(
          tester,
          LibraryBooksPage(
            titleKey: 'Prophets_Name_ismail',
            slots: _languageTestSlots,
            storage: storage,
            validator: (_) async {},
            downloadFactory: () => BookDownload(
              client: MockClient((request) async {
                requests.add(request.url.path);
                return http.Response(
                  '%PDF-1.7\n${request.url.path}\n%%EOF',
                  200,
                );
              }),
            ),
          ),
          locale,
        );
        for (final slot in _languageTestSlots) {
          expect(
            tester
                .widget<DropdownButton<String>>(_languagePicker(slot.titleKey))
                .value,
            slot.editions
                .singleWhere((book) => book.language == locale.languageCode)
                .id,
          );
        }
        final otherLanguage = locale.languageCode == 'en' ? 'ar' : 'en';
        for (final language in [otherLanguage, locale.languageCode]) {
          for (final slot in _languageTestSlots) {
            await _chooseLanguage(tester, slot.titleKey, language);
            final card = find.ancestor(
              of: _languagePicker(slot.titleKey),
              matching: find.byType(Card),
            );
            final download = find.descendant(
              of: card,
              matching: find.text('Biography_Download'.tr()),
            );
            await tester.ensureVisible(download);
            await tester.pumpAndSettle();
            await tester.tap(download);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pumpAndSettle();
            expect(
              find.descendant(
                of: card,
                matching: find.text('Biography_Read'.tr()),
              ),
              findsOneWidget,
            );
          }
        }
        expect(requests, [
          '/$otherLanguage/kids.pdf',
          '/$otherLanguage/full.pdf',
          '/${locale.languageCode}/kids.pdf',
          '/${locale.languageCode}/full.pdf',
        ]);
        expect(storage.saved.keys.toSet(), {
          for (final slot in _languageTestSlots)
            for (final edition in slot.editions) edition.id,
        });
        await _chooseLanguage(tester, 'Prophets_Kids_Story', otherLanguage);
        expect(find.text('Biography_Read'.tr()), findsNWidgets(2));
        expect(
          tester
              .widget<DropdownButton<String>>(
                _languagePicker('Prophets_Full_Story'),
              )
              .value,
          'prophet_ismail_full_${locale.languageCode}',
        );
        final delete = find.text('Biography_Delete_Download'.tr()).first;
        await tester.ensureVisible(delete);
        await tester.pumpAndSettle();
        await tester.tap(delete);
        await tester.pumpAndSettle();
        expect(storage.saved, hasLength(3));
        expect(
          storage.saved.containsKey('prophet_ismail_kids_$otherLanguage'),
          isFalse,
        );
        await _chooseLanguage(
          tester,
          'Prophets_Kids_Story',
          locale.languageCode,
        );
        expect(find.text('Biography_Read'.tr()), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('language selectors wrap with large text: $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        LibraryBooksPage(
          titleKey: 'Prophets_Name_ismail',
          slots: _languageTestSlots,
          storage: _Storage(),
        ),
        locale,
        scale: 2,
      );
      await _chooseLanguage(tester, 'Prophets_Kids_Story', 'ar');
      await _chooseLanguage(tester, 'Prophets_Full_Story', 'en');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic-only kids story stays downloadable: $locale', (
      tester,
    ) async {
      final slot = prophetCatalog
          .singleWhere((p) => p.id == 'ayyub')
          .stories
          .first;
      await _pump(
        tester,
        LibraryBooksPage(
          titleKey: 'Prophets_Name_ayyub',
          slots: [slot.librarySlot],
          storage: _Storage(),
        ),
        locale,
      );
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(
        find.text(
          'Books_Language'.tr(
            namedArgs: {'language': 'Books_Language_ar'.tr()},
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Books_Coming_Soon'.tr()), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets(
      'all 25 cards open correct story slots and restore list position: $locale',
      (tester) async {
        await _pump(tester, ProphetsPage(storage: _Storage()), locale);
        for (final prophet in prophetCatalog) {
          final card = find.byKey(ValueKey('prophet_${prophet.id}'));
          await tester.scrollUntilVisible(
            card,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(card);
          await tester.pumpAndSettle();
          final page = tester.widget<ProphetBooksPage>(
            find.byType(ProphetBooksPage),
          );
          expect(page.prophet.id, prophet.id);
          final shared = tester.widget<LibraryBooksPage>(
            find.byType(LibraryBooksPage),
          );
          expect(shared.slots, hasLength(2));
          expect(shared.slots.map((s) => s.titleKey), [
            'Prophets_Kids_Story',
            'Prophets_Full_Story',
          ]);
          expect(
            Directionality.of(
              tester.element(find.byType(ProphetBooksPage)),
            ).name,
            locale.languageCode == 'ar' ? 'rtl' : 'ltr',
          );
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(card.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'large text, offline sources and all lifespan states: $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prophet = prophetCatalog.singleWhere((p) => p.id == 'nuh');
        await _pump(
          tester,
          ProphetBooksPage(prophet: prophet, storage: _Storage()),
          locale,
          scale: 2,
        );
        final sourceButton = find.text('Prophets_Lifespan_Source'.tr());
        await tester.scrollUntilVisible(sourceButton, 180);
        await tester.pumpAndSettle();
        await tester.tap(sourceButton);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Prophets_Quran_Reference'.tr(namedArgs: {'reference': '29:14'}),
          ),
          findsOneWidget,
        );
        expect(find.text('Prophets_Lifespan_Nuh_Note'.tr()), findsWidgets);
        expect(tester.takeException(), isNull);
        const source = ProphetSourceReference(
          reference: 'Test source',
          url: 'https://example.com',
        );
        for (final status in [
          LifespanStatus.established,
          LifespanStatus.approximate,
          LifespanStatus.disputed,
        ]) {
          final label = prophetLifespanLabel(
            ProphetLifespan(years: 63, status: status, sourceReference: source),
            locale.toString(),
          );
          expect(
            label,
            contains(NumberFormat.decimalPattern(locale.toString()).format(63)),
          );
        }
        expect(
          prophetLifespanLabel(const ProphetLifespan(), locale.toString()),
          'Prophets_Lifespan_Unknown'.tr(),
        );
      },
    );

    testWidgets('empty story slots stay disabled without downloads: $locale', (
      tester,
    ) async {
      var downloads = 0;
      await _pump(
        tester,
        LibraryBooksPage(
          titleKey: 'Prophets_Title',
          storage: _Storage(),
          slots: const [
            LibraryBookSlot(titleKey: 'Prophets_Kids_Story', editions: []),
            LibraryBookSlot(titleKey: 'Prophets_Full_Story', editions: []),
          ],
          downloadFactory: () {
            downloads++;
            return BookDownload();
          },
        ),
        locale,
      );
      expect(find.text('Books_Coming_Soon'.tr()), findsNWidgets(2));
      for (final button in tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(downloads, 0);
    });
  }

  testWidgets('language selectors stay disabled during a download', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await _pump(
      tester,
      LibraryBooksPage(
        titleKey: 'Prophets_Name_ismail',
        slots: _languageTestSlots,
        storage: _Storage(),
        validator: (_) async {},
        downloadFactory: () =>
            BookDownload(client: MockClient((_) => response.future)),
      ),
      const Locale('en', 'US'),
    );
    await tester.tap(find.text('Biography_Download'.tr()).first);
    await tester.pump();
    for (final picker in tester.widgetList<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    )) {
      expect(picker.onChanged, isNull);
    }
    expect(find.text('Biography_Cancel'.tr()), findsOneWidget);
    response.complete(http.Response('%PDF-1.7\nexample\n%%EOF', 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    for (final picker in tester.widgetList<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    )) {
      expect(picker.onChanged, isNotNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'verified prophet downloads use the shared validator and independent IDs',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _Storage();
      var validations = 0;
      var operations = 0;
      const kids = LibraryBook(
        id: 'prophet_ismail_kids_en',
        titleKey: 'Prophets_Kids_Story',
        language: 'en',
        approximateBytes: 50,
        downloadUrl: 'https://example.com/kids.pdf',
      );
      const full = LibraryBook(
        id: 'prophet_ismail_full_en',
        titleKey: 'Prophets_Full_Story',
        language: 'en',
        approximateBytes: 50,
        downloadUrl: 'https://example.com/full.pdf',
      );
      await _pump(
        tester,
        LibraryBooksPage(
          titleKey: 'Prophets_Name_ismail',
          storage: storage,
          slots: const [
            LibraryBookSlot(titleKey: 'Prophets_Kids_Story', editions: [kids]),
            LibraryBookSlot(titleKey: 'Prophets_Full_Story', editions: [full]),
          ],
          validator: (_) async {
            validations++;
          },
          downloadFactory: () {
            operations++;
            return BookDownload(
              client: MockClient(
                (request) async =>
                    http.Response('%PDF-1.7\n${request.url.path}\n%%EOF', 200),
              ),
            );
          },
        ),
        const Locale('en', 'US'),
      );
      for (var index = 0; index < 2; index++) {
        await tester.tap(find.text('Biography_Download'.tr()).first);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(operations, index + 1);
        expect(find.text('Biography_Download_Error'.tr()), findsNothing);
      }
      expect(validations, 2);
      expect(storage.saved.keys, containsAll([kids.id, full.id]));
      expect(find.text('Biography_Read'.tr()), findsNWidgets(2));
      await tester.tap(find.text('Biography_Delete_Download'.tr()).first);
      await tester.pumpAndSettle();
      expect(storage.saved.keys, [full.id]);
      expect(find.text('Biography_Download'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offline reader keeps positions and bookmarks separate by prophet, edition and language',
    (tester) async {
      Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
      await tester.runAsync(() => pdfrxFlutterInitialize());
      final books = [
        for (final prophet in prophetCatalog)
          for (final slot in prophet.stories) ...slot.editions,
      ];
      final ids = [
        'prophet_ismail_kids_en',
        'prophet_ismail_full_en',
        'prophet_ismail_kids_ar',
        'prophet_nuh_kids_en',
      ];
      Future<PdfViewerController> open(String id) async {
        final book = books.singleWhere((book) => book.id == id);
        final path = File(
          book.downloadUri.pathSegments.skip(3).join('/'),
        ).absolute.path;
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
            startLocale: const Locale('en', 'US'),
            saveLocale: false,
            path: 'assets/translations',
            assetLoader: const _Loader(),
            child: _Host(
              BookReaderPage(
                book: book,
                sectionTitleKey: id.contains('ismail')
                    ? 'Prophets_Name_ismail'
                    : 'Prophets_Name_nuh',
                stored: StoredBook.file(path),
              ),
              1,
            ),
          ),
        );
        for (var attempt = 0; attempt < 200; attempt++) {
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

      Future<void> close() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      }

      for (final id in ids) {
        final controller = await open(id);
        expect(controller.pageNumber, 1);
        expect(find.byTooltip('Biography_Remove_Bookmark'.tr()), findsNothing);
        await controller.goToPage(pageNumber: 3, duration: Duration.zero);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getInt('biography_page_$id'), 3);
        await tester.tap(find.byTooltip('Biography_Add_Bookmark'.tr()));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Biography_Remove_Bookmark'.tr()),
          findsOneWidget,
        );
        expect(preferences.getStringList('biography_bookmarks_$id'), ['3']);
        await close();
      }
      final reopened = await open(ids.first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(reopened.pageNumber, 3);
      expect(find.byTooltip('Biography_Remove_Bookmark'.tr()), findsOneWidget);
      expect(find.text('Ismail · Kids Story'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close();
    },
  );
}
