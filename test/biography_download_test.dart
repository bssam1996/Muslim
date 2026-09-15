import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim/UI/biographies/biography_catalog.dart';
import 'package:muslim/UI/biographies/book_download.dart';
import 'package:muslim/UI/biographies/storage/book_storage.dart';
import 'package:muslim/UI/biographies/storage/book_storage_native.dart';

void main() {
  final book = biographyAuthors.single.books.first;
  final oldPdf = ascii.encode('%PDF-1.7\nold edition\n%%EOF');
  final newPdf = ascii.encode('%PDF-1.7\nnew edition\n%%EOF');
  late Directory directory;
  late NativeBookStorage storage;

  Future<void> accept(StoredBook book) async {}
  Future<List<int>> savedBytes() async =>
      File((await storage.read(book.id)).path!).readAsBytes();

  Future<void> run(BookDownload download, {BookValidator? validator}) =>
      download.run(
        book: book,
        storage: storage,
        validate: validator ?? accept,
        onProgress: (_, _) {},
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('muslim_book_test_');
    storage = NativeBookStorage(directoryProvider: () async => directory);
    await storage.save(book.id, Stream.value(oldPdf), accept);
  });

  tearDown(() async {
    // Only this test's uniquely created temporary directory is removed.
    await directory.delete(recursive: true);
  });

  test(
    'deletion removes only the selected PDF and allows downloading again',
    () async {
      final summary = biographyAuthors.single.books.last;
      await storage.save(summary.id, Stream.value(oldPdf), accept);
      final path = (await storage.read(book.id)).path!;

      await storage.delete(book.id);

      expect(await File(path).exists(), isFalse);
      expect(
        await NativeBookStorage(
          directoryProvider: () async => directory,
        ).contains(book.id),
        isFalse,
      );
      expect(await storage.contains(summary.id), isTrue);
      await expectLater(storage.read(book.id), throwsStateError);
      await storage.delete(book.id);
      await storage.save(book.id, Stream.value(newPdf), accept);
      expect(await savedBytes(), newPdf);
    },
  );

  test(
    'a validated update replaces the saved file and survives a new storage instance',
    () async {
      final requests = <Uri>[];
      final progress = <int>[];
      final download = BookDownload(
        client: MockClient.streaming((request, _) async {
          requests.add(request.url);
          return http.StreamedResponse(
            Stream.fromIterable([newPdf.sublist(0, 2), newPdf.sublist(2)]),
            200,
            contentLength: newPdf.length,
          );
        }),
      );
      await download.run(
        book: book,
        storage: storage,
        validate: (staged) async {
          expect(
            await savedBytes(),
            oldPdf,
            reason: 'Keep the old edition during validation',
          );
          expect(await File(staged.path!).readAsBytes(), newPdf);
        },
        onProgress: (received, total) {
          progress.add(received);
          expect(total, newPdf.length);
        },
      );
      storage = NativeBookStorage(directoryProvider: () async => directory);
      expect(await storage.contains(book.id), isTrue);
      expect(await savedBytes(), newPdf);
      expect(progress, [2, newPdf.length]);
      expect(requests.single.host, 'raw.githubusercontent.com');
      expect(
        Uri.decodeComponent(requests.single.path),
        contains('/Books/Prophet Muhammed Biography/Ibn Kathir/'),
      );
      expect(requests.single.queryParameters['download'], isNotEmpty);
      expect(
        await Directory('${directory.path}/biography_books').list().length,
        1,
      );
    },
  );

  for (final status in [404, 500]) {
    test('HTTP $status leaves the saved edition intact', () async {
      final download = BookDownload(
        client: MockClient((_) async => http.Response('error', status)),
      );
      await expectLater(run(download), throwsA(isA<http.ClientException>()));
      expect(await savedBytes(), oldPdf);
    });
  }

  for (final payload in ['<html>not a PDF</html>', '%PDF-1.7\ntruncated']) {
    test(
      'invalid or incomplete content does not replace a saved PDF: $payload',
      () async {
        final download = BookDownload(
          client: MockClient((_) async => http.Response(payload, 200)),
        );
        await expectLater(run(download), throwsFormatException);
        expect(await savedBytes(), oldPdf);
        expect(
          await Directory('${directory.path}/biography_books').list().length,
          1,
        );
      },
    );
  }

  test(
    'a short response with an EOF marker is rejected when the declared length differs',
    () async {
      final download = BookDownload(
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream.value(newPdf),
            200,
            contentLength: newPdf.length + 20,
          ),
        ),
      );
      await expectLater(run(download), throwsFormatException);
      expect(await savedBytes(), oldPdf);
    },
  );

  test('PDF parser rejection preserves the previous edition', () async {
    final download = BookDownload(
      client: MockClient((_) async => http.Response.bytes(newPdf, 200)),
    );
    await expectLater(
      run(
        download,
        validator: (_) async => throw const FormatException('Malformed PDF'),
      ),
      throwsFormatException,
    );
    expect(await savedBytes(), oldPdf);
  });

  test(
    'cancellation during validation preserves the previous edition',
    () async {
      final download = BookDownload(
        client: MockClient((_) async => http.Response.bytes(newPdf, 200)),
      );
      await expectLater(
        run(download, validator: (_) async => download.cancel()),
        throwsA(isA<BookDownloadCancelled>()),
      );
      expect(await savedBytes(), oldPdf);
    },
  );

  test('an interrupted stream cleans up the partial download', () async {
    Stream<List<int>> interrupted() async* {
      yield newPdf.sublist(0, 8);
      throw const SocketException('Connection lost');
    }

    final download = BookDownload(
      client: MockClient.streaming(
        (_, _) async => http.StreamedResponse(interrupted(), 200),
      ),
    );
    await expectLater(run(download), throwsA(isA<SocketException>()));
    expect(await savedBytes(), oldPdf);
    expect(
      await Directory('${directory.path}/biography_books').list().length,
      1,
    );
  });

  test(
    'a failed first download is never marked as available offline',
    () async {
      final summary = biographyAuthors.single.books.last;
      final download = BookDownload(
        client: MockClient((_) async => http.Response('Not found', 404)),
      );
      await expectLater(
        download.run(
          book: summary,
          storage: storage,
          validate: accept,
          onProgress: (_, _) {},
        ),
        throwsA(isA<http.ClientException>()),
      );
      expect(await storage.contains(summary.id), isFalse);
    },
  );
}
