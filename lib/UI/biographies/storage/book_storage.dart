import 'dart:typed_data';

import 'book_storage_native.dart'
    if (dart.library.js_interop) 'book_storage_web.dart'
    as platform;

class StoredBook {
  const StoredBook.file(String this.path) : bytes = null;
  const StoredBook.memory(Uint8List this.bytes) : path = null;

  final String? path;
  final Uint8List? bytes;
}

typedef BookValidator = Future<void> Function(StoredBook book);

abstract class BookStorage {
  Future<bool> contains(String id);
  Future<StoredBook> read(String id);

  // Removes the downloaded copy. An already absent book is a no-op.
  Future<void> delete(String id);

  // Implementations must validate the staged download before replacing the
  // existing copy, and discard staging data on failure or cancellation.
  Future<void> save(String id, Stream<List<int>> bytes, BookValidator validate);
}

BookStorage createBookStorage() => platform.createBookStorage();
