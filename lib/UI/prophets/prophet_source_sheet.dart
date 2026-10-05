import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'prophet_catalog.dart';

String prophetSourceLabel(ProphetSourceReference source) {
  if (source.reference.startsWith('Quran ')) {
    return 'Prophets_Quran_Reference'.tr(
      namedArgs: {'reference': source.reference.substring('Quran '.length)},
    );
  }
  if (source.reference.startsWith('Sahih al-Bukhari ')) {
    return 'Prophets_Bukhari_Reference'.tr(
      namedArgs: {
        'reference': source.reference.substring('Sahih al-Bukhari '.length),
      },
    );
  }
  if (source == prophetChronologySource) {
    return 'Prophets_Chronology_Reference'.tr();
  }
  return source.reference;
}

Future<void> showProphetSource(
  BuildContext context, {
  ProphetSourceReference? source,
  String? noteKey,
  String? yearBasis,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Prophets_Source'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (noteKey != null) Text(noteKey.tr()),
          if (yearBasis != null) Text(yearBasis.tr()),
          if (source != null) ...[
            const SizedBox(height: 12),
            SelectableText(prophetSourceLabel(source)),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text('Prophets_Open_Source'.tr()),
              onPressed: () async {
                try {
                  final opened = await launchUrl(
                    Uri.parse(source.url),
                    mode: LaunchMode.externalApplication,
                  );
                  if (opened) return;
                } catch (_) {
                  // The reference above remains readable without a browser.
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Prophets_Source_Open_Error'.tr())),
                );
              },
            ),
          ],
        ],
      ),
    ),
  ),
);
