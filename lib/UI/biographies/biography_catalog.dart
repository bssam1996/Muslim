class BiographyAuthor {
  const BiographyAuthor({required this.nameKey, required this.books});

  final String nameKey;
  final List<BiographyBook> books;
}

class BiographyBook {
  const BiographyBook({
    required this.id,
    required this.titleKey,
    required this.fileName,
    required this.directory,
    required this.approximateBytes,
  });

  // Keep IDs stable when replacing a PDF so downloads and reading positions
  // continue to belong to the same book.
  final String id;
  final String titleKey;
  final String directory;
  final String fileName;
  final int approximateBytes;

  Uri get downloadUri => Uri.https(
    'raw.githubusercontent.com',
    '/bssam1996/Muslim/main/Books/Prophet Muhammed Biography/$directory/$fileName',
  );
}

const biographyAuthors = <BiographyAuthor>[
  BiographyAuthor(
    nameKey: 'Biography_Author_Ibn_Kathir',
    books: [
      BiographyBook(
        id: 'ibn_kathir_full',
        titleKey: 'Biography_Full_Book',
        directory: 'Ibn Kathir',
        fileName: 'The Prophetic Biography by Ibn Kathir.pdf',
        approximateBytes: 59768414,
      ),
      BiographyBook(
        id: 'ibn_kathir_summary',
        titleKey: 'Biography_Summary',
        directory: 'Ibn Kathir',
        fileName: 'The Prophetic Biography by Ibn Kathir Summary.pdf',
        approximateBytes: 589749,
      ),
    ],
  ),
];
