@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/biographies/storage/book_storage_web.dart';
import 'package:web/web.dart' as web;

void main() {
  test(
    'browser downloads persist and a failed replacement preserves the old copy',
    () async {
      final storage = WebBookStorage();
      final id = 'test_${DateTime.now().microsecondsSinceEpoch}';
      final oldBytes = Uint8List.fromList([1, 2, 3]);
      final newBytes = Uint8List.fromList([4, 5, 6]);
      final cache = await web.window.caches
          .open('muslim-biography-books-v1')
          .toDart;
      final key = Uri.base
          .resolve('biography-downloads/$id.pdf')
          .toString()
          .toJS;
      addTearDown(() async {
        await cache.delete(key).toDart;
      });

      expect(await storage.contains(id), isFalse);
      await storage.save(id, Stream.value(oldBytes), (_) async {});
      expect(await WebBookStorage().contains(id), isTrue);
      expect((await WebBookStorage().read(id)).bytes, oldBytes);

      await expectLater(
        storage.save(
          id,
          Stream.value(newBytes),
          (_) async => throw const FormatException('Invalid PDF'),
        ),
        throwsFormatException,
      );
      expect((await storage.read(id)).bytes, oldBytes);

      await storage.save(id, Stream.value(newBytes), (_) async {});
      expect((await WebBookStorage().read(id)).bytes, newBytes);

      await storage.delete(id);
      expect(await cache.match(key).toDart, isNull);
      expect(await WebBookStorage().contains(id), isFalse);
      await expectLater(storage.read(id), throwsStateError);
      await storage.delete(id);
      await storage.save(id, Stream.value(oldBytes), (_) async {});
      expect((await WebBookStorage().read(id)).bytes, oldBytes);
    },
  );
}
