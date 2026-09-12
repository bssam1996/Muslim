import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dua_preferences.dart';
import 'models/dua_catalog.dart';
import 'widgets/dua_sources.dart';
import 'widgets/dua_style.dart';

String duaShareText(
  DuaEntry entry,
  DuaCatalog catalog, {
  bool meaning = false,
}) => [
  entry.title.en,
  entry.title.ar,
  for (final block in entry.blocks) ...[
    block.arabic,
    if (meaning) block.meaning,
  ],
  for (final source in catalog.sourcesFor([entry]))
    '${source.title.en}\n${source.url}',
].join('\n\n');

class DuaReader extends StatefulWidget {
  const DuaReader({
    super.key,
    required this.entry,
    required this.catalog,
    required this.preferences,
    this.onTag,
  });
  final DuaEntry entry;
  final DuaCatalog catalog;
  final DuaPreferences preferences;
  final ValueChanged<String>? onTag;
  @override
  State<DuaReader> createState() => _DuaReaderState();
}

class _DuaReaderState extends State<DuaReader> {
  final _scroll = ScrollController();
  final _sourceAnchor = GlobalKey();
  final _counts = <String, int>{};
  bool _shareMeaning = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _sources() {
    final target = _sourceAnchor.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  Future<void> _export(BuildContext context, {required bool share}) async {
    try {
      if (share) {
        final box = context.findRenderObject() as RenderBox;
        await SharePlus.instance.share(
          ShareParams(
            text: duaShareText(
              widget.entry,
              widget.catalog,
              meaning: _shareMeaning,
            ),
            sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      } else {
        await Clipboard.setData(ClipboardData(text: widget.entry.arabic));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(dl(context, 'Arabic copied', 'تم نسخ النص العربي')),
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dl(
                context,
                'Could not export this duaa.',
                'تعذر نسخ الدعاء أو مشاركته.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => DuaStyle(
    child: Builder(
      builder: (context) => AnimatedBuilder(
        animation: widget.preferences,
        builder: (context, _) {
          final e = widget.entry, prefs = widget.preferences;
          final colors = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(
              title: Text(dt(context, e.title)),
              actions: [
                IconButton(
                  key: const ValueKey('duaa-bookmark'),
                  tooltip: dl(context, 'Toggle favourite', 'تغيير المفضلة'),
                  onPressed: () => prefs.toggle(e.id),
                  icon: Icon(
                    prefs.favourites.contains(e.id)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          dt(context, e.title),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          duaOriginLabel(context, e, widget.catalog),
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          e.applicability == 'reportedOccasion'
                              ? dl(
                                  context,
                                  'Reported occasion',
                                  'مناسبة واردة في النص',
                                )
                              : dl(context, 'General supplication', 'دعاء عام'),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            key: const ValueKey('duaa-jump-sources'),
                            onPressed: _sources,
                            icon: const Icon(Icons.menu_book_outlined),
                            label: Text(
                              dl(context, 'Check sources', 'التحقق من المصادر'),
                            ),
                          ),
                        ),
                        if (prefs.error)
                          DuaNotice(
                            text: dl(
                              context,
                              'Settings could not be restored or saved.',
                              'تعذر استعادة الإعدادات أو حفظها.',
                            ),
                          ),
                        Card(
                          color: colors.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  dl(
                                    context,
                                    'When to say it / What to do',
                                    'متى يقال / ما عليك فعله',
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 10),
                                Text(dt(context, e.guidance)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(dl(context, 'Text size', 'حجم النص')),
                            IconButton(
                              key: const ValueKey('duaa-font-minus'),
                              tooltip: dl(
                                context,
                                'Smaller text',
                                'تصغير النص',
                              ),
                              onPressed: prefs.fontSize > 20
                                  ? () => prefs.resize(-2)
                                  : null,
                              icon: const Icon(Icons.text_decrease),
                            ),
                            Text('${prefs.fontSize.round()}'),
                            IconButton(
                              key: const ValueKey('duaa-font-plus'),
                              tooltip: dl(context, 'Larger text', 'تكبير النص'),
                              onPressed: prefs.fontSize < 40
                                  ? () => prefs.resize(2)
                                  : null,
                              icon: const Icon(Icons.text_increase),
                            ),
                            TextButton(
                              onPressed: prefs.resetFont,
                              child: Text(
                                dl(context, 'Default size', 'الحجم الافتراضي'),
                              ),
                            ),
                          ],
                        ),
                        if (e.blocks.any((b) => b.transliteration.isNotEmpty))
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              dl(
                                context,
                                'Transliteration • pronunciation aid',
                                'النطق بالحروف اللاتينية • للمساعدة',
                              ),
                            ),
                            value: prefs.transliteration,
                            onChanged: prefs.showTransliteration,
                          ),
                        for (final block in e.blocks)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Card(
                              color: colors.surfaceContainerLow,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SelectableText(
                                      block.arabic,
                                      key: ValueKey('recitation-${block.id}'),
                                      textDirection: TextDirection.rtl,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Uthman',
                                        fontSize: prefs.fontSize,
                                        height: 1.9,
                                      ),
                                    ),
                                    if (!duaArabic(context)) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        block.meaning,
                                        textDirection: TextDirection.ltr,
                                      ),
                                    ],
                                    if (prefs.transliteration &&
                                        block.transliteration.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        block.transliteration,
                                        textDirection: TextDirection.ltr,
                                      ),
                                    ],
                                    if (block.repeat != null) ...[
                                      const SizedBox(height: 18),
                                      Text(
                                        dl(
                                          context,
                                          'Reported repetitions: ${block.repeat}',
                                          'التكرار الوارد: ${block.repeat}',
                                        ),
                                      ),
                                      Semantics(
                                        liveRegion: true,
                                        child: Text(
                                          dl(
                                            context,
                                            '${_counts[block.id] ?? 0} of ${block.repeat}',
                                            '${_counts[block.id] ?? 0} من ${block.repeat}',
                                          ),
                                          key: ValueKey('count-${block.id}'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton.icon(
                                        key: ValueKey(
                                          'count-button-${block.id}',
                                        ),
                                        onPressed:
                                            (_counts[block.id] ?? 0) >=
                                                block.repeat!
                                            ? null
                                            : () => setState(
                                                () => _counts[block.id] =
                                                    (_counts[block.id] ?? 0) +
                                                    1,
                                              ),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        label: Text(
                                          dl(
                                            context,
                                            'Count recitation',
                                            'عدّ التلاوة',
                                          ),
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 12,
                                        children: [
                                          TextButton.icon(
                                            key: ValueKey('undo-${block.id}'),
                                            onPressed:
                                                (_counts[block.id] ?? 0) == 0
                                                ? null
                                                : () => setState(
                                                    () => _counts[block.id] =
                                                        _counts[block.id]! - 1,
                                                  ),
                                            icon: const Icon(Icons.undo),
                                            label: Text(
                                              dl(context, 'Undo', 'تراجع'),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => setState(
                                              () => _counts[block.id] = 0,
                                            ),
                                            child: Text(
                                              dl(
                                                context,
                                                'Reset count',
                                                'تصفير العدّ',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Text(
                                      dl(
                                        context,
                                        'Text${block.repeat == null ? '' : ' and count'} reference:',
                                        'مرجع النص${block.repeat == null ? '' : ' والعدد'}:',
                                      ),
                                    ),
                                    for (final id in block.sourceIds)
                                      TextButton(
                                        onPressed: _sources,
                                        child: Text(
                                          dt(
                                            context,
                                            widget.catalog.sources[id]!.title,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _export(context, share: false),
                              icon: const Icon(Icons.copy),
                              label: Text(
                                dl(context, 'Copy Arabic', 'نسخ العربية'),
                              ),
                            ),
                            Builder(
                              builder: (buttonContext) => OutlinedButton.icon(
                                onPressed: () =>
                                    _export(buttonContext, share: true),
                                icon: const Icon(Icons.share_outlined),
                                label: Text(
                                  dl(
                                    context,
                                    'Share with sources',
                                    'مشاركة مع المصادر',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            dl(
                              context,
                              'Include English meaning when sharing',
                              'تضمين المعنى الإنجليزي عند المشاركة',
                            ),
                          ),
                          value: _shareMeaning,
                          onChanged: (value) =>
                              setState(() => _shareMeaning = value),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final tag in e.tags)
                              ActionChip(
                                label: Text(
                                  dt(context, widget.catalog.tags[tag]!),
                                ),
                                onPressed: widget.onTag == null
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        widget.onTag!(tag);
                                      },
                              ),
                          ],
                        ),
                        if (e.related.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            dl(
                              context,
                              'Related supplications',
                              'أدعية مرتبطة',
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          for (final id in e.related)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                dt(
                                  context,
                                  widget.catalog.entries
                                      .singleWhere((entry) => entry.id == id)
                                      .title,
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward),
                              onTap: () {
                                prefs.opened(id);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => DuaReader(
                                      entry: widget.catalog.entries.singleWhere(
                                        (entry) => entry.id == id,
                                      ),
                                      catalog: widget.catalog,
                                      preferences: prefs,
                                      onTag: widget.onTag == null
                                          ? null
                                          : (tag) {
                                              Navigator.pop(context);
                                              widget.onTag!(tag);
                                            },
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                        DuaSources(
                          key: _sourceAnchor,
                          sources: widget.catalog.sourcesFor([e]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
