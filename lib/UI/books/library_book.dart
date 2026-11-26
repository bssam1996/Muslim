class LibraryBook {
  const LibraryBook({
    required this.id,
    required this.titleKey,
    required this.approximateBytes,
    required this.language,
    this.downloadUrl,
    this.source,
    this.sourceKey,
    this.noteKey,
    this.available = true,
  });

  final String id;
  final String titleKey;
  final int approximateBytes;
  final String language;
  final String? downloadUrl;
  final String? source;
  final String? sourceKey;
  final String? noteKey;
  // Set only after the published PDF has been verified.
  final bool available;

  Uri get downloadUri => Uri.parse(downloadUrl!);
}

class LibraryBookSlot {
  const LibraryBookSlot({required this.titleKey, required this.editions});

  final String titleKey;
  final List<LibraryBook> editions;

  LibraryBook? select(String language) {
    for (final book in editions) {
      if (book.language == language && book.available) return book;
    }
    for (final book in editions) {
      if (book.available) return book;
    }
    for (final book in editions) {
      if (book.language == language) return book;
    }
    return editions.isEmpty ? null : editions.first;
  }
}
