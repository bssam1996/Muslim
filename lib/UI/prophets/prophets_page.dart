import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../biographies/biography_scaffold.dart';
import '../biographies/storage/book_storage.dart';
import 'prophet_artwork.dart';
import 'prophet_books_page.dart';
import 'prophet_catalog.dart';
import 'prophet_source_sheet.dart';

const prophetsHomeIcon = 'assets/prophets/prophets.png';

class ProphetsPage extends StatelessWidget {
  const ProphetsPage({super.key, this.storage});
  final BookStorage? storage;

  @override
  Widget build(BuildContext context) {
    final prophets = [...prophetCatalog]
      ..sort((a, b) => a.chronologicalOrder.compareTo(b.chronologicalOrder));
    return BiographyScaffold(
      appBar: AppBar(title: Text('Prophets_Title'.tr())),
      body: ListView.builder(
        key: const PageStorageKey('prophets_list'),
        padding: const EdgeInsets.all(16),
        itemCount: prophets.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prophets_Intro'.tr(), style: biographyHeadingStyle),
                  const SizedBox(height: 8),
                  Text('Prophets_Chronology_Note'.tr()),
                  TextButton.icon(
                    onPressed: () => showProphetSource(
                      context,
                      source: prophetChronologySource,
                      noteKey: 'Prophets_Chronology_Note',
                    ),
                    icon: const Icon(Icons.info_outline),
                    label: Text('Prophets_Source'.tr()),
                  ),
                ],
              ),
            );
          }
          final prophet = prophets[index - 1];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              button: true,
              child: InkWell(
                key: ValueKey('prophet_${prophet.id}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProphetBooksPage(prophet: prophet, storage: storage),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: ProphetArtwork(asset: prophet.imageAsset)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              prophet.nameKey.tr(),
                              style: biographyHeadingStyle,
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(prophet.imageCaptionKey.tr()),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
