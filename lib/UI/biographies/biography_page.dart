import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../books/library_book.dart';
import '../books/library_books_page.dart';
import 'biography_catalog.dart';
import 'biography_scaffold.dart';
import 'storage/book_storage.dart';

const biographyIcon = 'assets/biographies/prophet_muhammed_biography_2.png';

class BiographyPage extends StatelessWidget {
  const BiographyPage({super.key});

  @override
  Widget build(BuildContext context) => BiographyScaffold(
    appBar: AppBar(title: Text('Biography_Title'.tr())),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Image.asset(biographyIcon, height: 112),
        const SizedBox(height: 24),
        Text('Biography_Choose_Author'.tr(), style: biographyHeadingStyle),
        const SizedBox(height: 12),
        for (final author in biographyAuthors)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(author.nameKey.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BiographyBooksPage(author: author),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class BiographyBooksPage extends StatelessWidget {
  const BiographyBooksPage({
    super.key,
    required this.author,
    this.storage,
    this.validator,
  });

  final BiographyAuthor author;
  final BookStorage? storage;
  final BookValidator? validator;

  @override
  Widget build(BuildContext context) => LibraryBooksPage(
    titleKey: author.nameKey,
    slots: [
      for (final book in author.books)
        LibraryBookSlot(titleKey: book.titleKey, editions: [book]),
    ],
    storage: storage,
    validator: validator,
  );
}
