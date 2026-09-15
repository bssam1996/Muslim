import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/biographies/biography_catalog.dart';
import 'package:muslim/UI/biographies/book_reader_page.dart';
import 'package:muslim/UI/biographies/storage/book_storage.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
    await pdfrxFlutterInitialize();
  });

  for (final book in biographyAuthors.single.books) {
    test(
      'the actual ${book.id} PDF opens and renders first and last pages',
      () async {
        final path = File(
          'Books/Prophet Muhammed Biography/${book.directory}/${book.fileName}',
        ).absolute.path;
        await validateBookPdf(StoredBook.file(path));
        final document = await PdfDocument.openFile(path);
        try {
          expect(document.pages, isNotEmpty);
          for (final page in [document.pages.first, document.pages.last]) {
            final image = await page.render(
              fullWidth: 200,
              fullHeight: 200 * page.height / page.width,
            );
            expect(image, isNotNull);
            expect(image!.pixels, isNotEmpty);
            image.dispose();
          }
        } finally {
          await document.dispose();
        }
      },
    );
  }
}
