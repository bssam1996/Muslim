import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'book_storage.dart';

BookStorage createBookStorage() => WebBookStorage();

class WebBookStorage implements BookStorage {
  Future<web.Cache> get _cache =>
      web.window.caches.open('muslim-biography-books-v1').toDart;

  JSString _key(String id) => Uri.base
      .resolve('biography-downloads/${Uri.encodeComponent(id)}.pdf')
      .toString()
      .toJS;

  @override
  Future<bool> contains(String id) async =>
      await (await _cache).match(_key(id)).toDart != null;

  @override
  Future<StoredBook> read(String id) async {
    final response = await (await _cache).match(_key(id)).toDart;
    if (response == null) throw StateError('Book is not downloaded');
    final buffer = await response.arrayBuffer().toDart;
    return StoredBook.memory(buffer.toDart.asUint8List());
  }

  @override
  Future<void> delete(String id) async {
    await (await _cache).delete(_key(id)).toDart;
  }

  @override
  Future<void> save(
    String id,
    Stream<List<int>> bytes,
    BookValidator validate,
  ) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in bytes) {
      builder.add(chunk);
    }
    final data = builder.takeBytes();
    await validate(StoredBook.memory(data));
    // Cache.put replaces a single entry atomically, including on quota failure.
    await (await _cache).put(_key(id), web.Response(data.toJS)).toDart;
  }
}
