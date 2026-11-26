import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/biographies/biography_catalog.dart';
import 'package:muslim/UI/books/library_book.dart';
import 'package:muslim/UI/prophets/prophet_catalog.dart';

void main() {
  test(
    'complete roster, stable IDs, exact PDF paths and artwork registrations',
    () {
      expect(prophetCatalog, hasLength(25));
      expect(prophetCatalog.map((p) => p.id).toSet(), hasLength(25));
      expect(
        prophetCatalog.map((p) => p.chronologicalOrder).toSet(),
        hasLength(25),
      );
      expect(prophetCatalog.first.id, 'adam');
      expect(prophetCatalog.last.id, 'muhammad');
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final manifest =
          jsonDecode(File('Books/Prophets/sources.json').readAsStringSync())
              as Map<String, dynamic>;
      final sourceBooks = {
        for (final book in manifest['books'] as List)
          book['file'] as String: book,
      };
      final verified =
          jsonDecode(File('tool/prophet_books_status.json').readAsStringSync())
              as Map<String, dynamic>;
      final ids = {
        for (final author in biographyAuthors)
          for (final book in author.books) book.id,
      };
      final discovered = <String>{};
      for (final prophet in prophetCatalog) {
        expect(prophet.chronologicalOrder, greaterThan(0));
        expect(File(prophet.imageAsset).existsSync(), isTrue);
        expect(pubspec, contains('"assets/prophets/${prophet.id}/"'));
        expect(prophet.stories.map((s) => s.kind), ProphetStoryKind.values);
        for (final slot in prophet.stories) {
          for (final book in slot.editions) {
            expect(ids.add(book.id), isTrue, reason: 'Duplicate ${book.id}');
            expect(book.id, matches(r'^[a-z0-9_]+$'));
            expect(
              book.id,
              'prophet_${prophet.id}_${slot.kind.name}_${book.language}',
            );
            expect(book.titleKey, slot.titleKey);
            expect(book.downloadUri.host, 'raw.githubusercontent.com');
            final relative = book.downloadUri.pathSegments.skip(5).join('/');
            discovered.add(relative);
            expect(sourceBooks[relative], isNotNull, reason: relative);
            expect(book.approximateBytes, sourceBooks[relative]['bytes']);
            expect(
              File('Books/Prophets/$relative').lengthSync(),
              book.approximateBytes,
            );
            expect(book.language, sourceBooks[relative]['language']);
            expect(
              book.available,
              verified[relative] == sourceBooks[relative]['sha256'],
              reason: 'Only verified editions may download: $relative',
            );
          }
        }
      }
      expect(discovered, sourceBooks.keys.toSet());
      expect(discovered, hasLength(92));
    },
  );

  test(
    'every displayed lifespan and story description has reviewed metadata',
    () {
      for (final prophet in prophetCatalog) {
        final life = prophet.lifespan;
        if (life.years != null) {
          expect(life.years, greaterThan(0));
          expect(life.status, isNot(LifespanStatus.unknown));
          expect(life.sourceReference?.reference, isNotEmpty);
        } else {
          expect(life.status, LifespanStatus.unknown);
        }
        expect(prophet.miracleSummary?.sourceReference.reference, isNotEmpty);
      }
      expect(
        prophetCatalog.singleWhere((p) => p.id == 'nuh').lifespan.years,
        isNull,
      );
      expect(
        prophetCatalog.singleWhere((p) => p.id == 'muhammad').lifespan.years,
        63,
      );
      expect(
        prophetCatalog
            .singleWhere((p) => p.id == 'dhul_kifl')
            .miracleSummary!
            .kind,
        ProphetSummaryKind.storyHighlight,
      );
    },
  );

  test('all content keys and placeholders match between languages', () {
    final en =
        jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
            as Map;
    final ar =
        jsonDecode(File('assets/translations/ar-EG.json').readAsStringSync())
            as Map;
    final keys = en.keys
        .where((key) => key.startsWith('Prophets_') || key.startsWith('Books_'))
        .toSet();
    expect(
      keys,
      ar.keys
          .where(
            (key) => key.startsWith('Prophets_') || key.startsWith('Books_'),
          )
          .toSet(),
    );
    for (final prophet in prophetCatalog) {
      for (final key in [
        prophet.nameKey,
        prophet.imageCaptionKey,
        prophet.miracleSummary!.descriptionKey,
        prophet.lifespan.noteKey!,
      ]) {
        expect(keys, contains(key));
      }
    }
    final placeholders = RegExp(r'\{[^}]+\}');
    for (final key in keys) {
      expect(en[key], isNotEmpty);
      expect(ar[key], isNotEmpty);
      expect(
        placeholders.allMatches(en[key]).map((m) => m.group(0)).toSet(),
        placeholders.allMatches(ar[key]).map((m) => m.group(0)).toSet(),
      );
    }
    expect(
      ar['Prophets_Title'],
      '\u0627\u0644\u0623\u0646\u0628\u064a\u0627\u0621',
    );
  });

  test(
    'edition selection prefers the UI language and falls back only to supplied books',
    () {
      const ar = LibraryBook(
        id: 'ar',
        titleKey: 't',
        approximateBytes: 1,
        language: 'ar',
      );
      const en = LibraryBook(
        id: 'en',
        titleKey: 't',
        approximateBytes: 1,
        language: 'en',
      );
      const pending = LibraryBook(
        id: 'pending',
        titleKey: 't',
        approximateBytes: 1,
        language: 'en',
        available: false,
      );
      expect(
        const LibraryBookSlot(titleKey: 't', editions: [ar, en]).select('en'),
        en,
      );
      expect(
        const LibraryBookSlot(titleKey: 't', editions: [ar, en]).select('ar'),
        ar,
      );
      expect(
        const LibraryBookSlot(
          titleKey: 't',
          editions: [ar, pending],
        ).select('en'),
        ar,
      );
      expect(
        const LibraryBookSlot(titleKey: 't', editions: []).select('en'),
        isNull,
      );
    },
  );
}
