import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../biographies/biography_scaffold.dart';
import '../biographies/storage/book_storage.dart';
import '../books/library_books_page.dart';
import 'prophet_artwork.dart';
import 'prophet_catalog.dart';
import 'prophet_source_sheet.dart';

String prophetLifespanLabel(ProphetLifespan lifespan, String locale) {
  if (lifespan.years == null) return 'Prophets_Lifespan_Unknown'.tr();
  final key = switch (lifespan.status) {
    LifespanStatus.established => 'Prophets_Lifespan_Established',
    LifespanStatus.approximate => 'Prophets_Lifespan_Approximate',
    LifespanStatus.disputed => 'Prophets_Lifespan_Reported',
    LifespanStatus.unknown => 'Prophets_Lifespan_Unknown',
  };
  return key.tr(
    namedArgs: {
      'years': NumberFormat.decimalPattern(locale).format(lifespan.years),
    },
  );
}

class ProphetBooksPage extends StatelessWidget {
  const ProphetBooksPage({
    super.key,
    required this.prophet,
    this.storage,
    this.validator,
  });
  final Prophet prophet;
  final BookStorage? storage;
  final BookValidator? validator;

  @override
  Widget build(BuildContext context) {
    final lifespan = prophet.lifespan;
    final summary = prophet.miracleSummary;
    return LibraryBooksPage(
      key: ValueKey('books_${prophet.id}_${context.locale.languageCode}'),
      titleKey: prophet.nameKey,
      slots: [for (final story in prophet.stories) story.librarySlot],
      storage: storage,
      validator: validator,
      backgroundAsset: prophet.imageAsset,
      header: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ProphetArtwork(asset: prophet.imageAsset, height: 160),
            ),
            const SizedBox(height: 16),
            Text(prophet.nameKey.tr(), style: biographyHeadingStyle),
            const SizedBox(height: 8),
            Text(prophet.imageCaptionKey.tr()),
            const SizedBox(height: 8),
            Text(prophetLifespanLabel(lifespan, context.locale.toString())),
            if (lifespan.noteKey != null) ...[
              const SizedBox(height: 4),
              Text(lifespan.noteKey!.tr()),
            ],
            TextButton.icon(
              onPressed: () => showProphetSource(
                context,
                source: lifespan.sourceReference,
                noteKey: lifespan.noteKey,
                yearBasis: lifespan.yearBasis,
              ),
              icon: const Icon(Icons.info_outline),
              label: Text('Prophets_Lifespan_Source'.tr()),
            ),
            if (summary != null) ...[
              const SizedBox(height: 12),
              Text(
                (summary.kind == ProphetSummaryKind.miracle
                        ? 'Prophets_Miracle'
                        : 'Prophets_Story_Highlight')
                    .tr(),
                style: biographyHeadingStyle,
              ),
              const SizedBox(height: 8),
              Text(summary.descriptionKey.tr()),
              TextButton.icon(
                onPressed: () =>
                    showProphetSource(context, source: summary.sourceReference),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(prophetSourceLabel(summary.sourceReference)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
