import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'library_book.dart';
import '../biographies/storage/book_storage.dart';

class BookDownloadCancelled implements Exception {}

class BookDownload {
  BookDownload({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _client.close();
  }

  void _checkCancelled() {
    if (_cancelled) throw BookDownloadCancelled();
  }

  Future<void> run({
    required LibraryBook book,
    required BookStorage storage,
    required BookValidator validate,
    required void Function(int received, int? total) onProgress,
  }) async {
    try {
      _checkCancelled();
      // A fresh URL bypasses stale intermediary/browser caches on re-download.
      final uri = book.downloadUri.replace(
        queryParameters: {
          'download': DateTime.now().microsecondsSinceEpoch.toString(),
        },
      );
      final response = await _client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      _checkCancelled();
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}', uri);
      }
      final total = response.contentLength;
      Stream<List<int>> checkedStream() async* {
        var received = 0;
        final header = <int>[];
        var tail = <int>[];
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 45),
        )) {
          _checkCancelled();
          received += chunk.length;
          if (header.length < 5) {
            header.addAll(chunk.take(5 - header.length));
          }
          if (header.length == 5 &&
              ascii.decode(header, allowInvalid: true) != '%PDF-') {
            throw const FormatException('Response is not a PDF');
          }
          tail = chunk.length >= 1024
              ? chunk.sublist(chunk.length - 1024)
              : [...tail, ...chunk];
          if (tail.length > 1024) tail = tail.sublist(tail.length - 1024);
          onProgress(received, total);
          yield chunk;
        }
        _checkCancelled();
        if (received < 5 ||
            (total != null && received != total) ||
            !ascii.decode(tail, allowInvalid: true).contains('%%EOF')) {
          throw const FormatException('Incomplete PDF download');
        }
      }

      await storage.save(book.id, checkedStream(), (staged) async {
        _checkCancelled();
        await validate(staged);
        _checkCancelled();
      });
    } catch (_) {
      if (_cancelled) throw BookDownloadCancelled();
      rethrow;
    } finally {
      _client.close();
    }
  }
}
