import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'book_storage.dart';

BookStorage createBookStorage() => NativeBookStorage();

class NativeBookStorage implements BookStorage {
  NativeBookStorage({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _file(String id) async {
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id');
    }
    final root = await _directoryProvider();
    final directory = Directory('${root.path}/biography_books');
    await directory.create(recursive: true);
    return File('${directory.path}/$id.pdf');
  }

  @override
  Future<bool> contains(String id) async {
    final file = await _file(id);
    return await file.exists() && await file.length() > 0;
  }

  @override
  Future<StoredBook> read(String id) async {
    final file = await _file(id);
    if (!await file.exists()) throw StateError('Book is not downloaded');
    return StoredBook.file(file.path);
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> save(
    String id,
    Stream<List<int>> bytes,
    BookValidator validate,
  ) async {
    final target = await _file(id);
    final staging = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );
    try {
      // Await each write to keep memory bounded even on slow storage.
      final file = await staging.open(mode: FileMode.write);
      try {
        await for (final chunk in bytes) {
          await file.writeFrom(chunk);
        }
        await file.flush();
      } finally {
        await file.close();
      }
      await validate(StoredBook.file(staging.path));
      // Same-directory rename replaces the old file only after validation.
      await staging.rename(target.path);
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }
}
