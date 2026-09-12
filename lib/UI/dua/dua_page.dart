import 'package:flutter/material.dart';
import '../azkar/azkar_page.dart';
import 'data/dua_repository.dart';
import 'dua_preferences.dart';
import 'dua_reader.dart';
import 'legacy_dua_page.dart';
import 'models/dua_catalog.dart';
import 'pilgrimage/pilgrimage_journey_page.dart';
import 'search/dua_library_search.dart';
import 'widgets/dua_sources.dart';
import 'widgets/dua_style.dart';

class DuaPageClass extends StatefulWidget {
  const DuaPageClass({super.key});
  @override
  State<DuaPageClass> createState() => _DuaPageClassState();
}

class _DuaPageClassState extends State<DuaPageClass> {
  late Future<DuaCatalog> _catalog = DuaRepository.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<DuaCatalog>(
    future: _catalog,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Duaa')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dl(
                    context,
                    'The library could not be loaded.',
                    'تعذر تحميل المكتبة.',
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _catalog = DuaRepository.load()),
                  child: Text(dl(context, 'Retry', 'إعادة المحاولة')),
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      // Preserve the existing public destination until the new dataset is approved.
      if (snapshot.data!.entries.isEmpty) return const LegacyDuaPageClass();
      return DuaLibraryPage(catalog: snapshot.data!);
    },
  );
}

class DuaLibraryPage extends StatefulWidget {
  const DuaLibraryPage({super.key, required this.catalog});
  final DuaCatalog catalog;
  @override
  State<DuaLibraryPage> createState() => _DuaLibraryPageState();
}

class _DuaLibraryPageState extends State<DuaLibraryPage> {
  late final _engine = DuaLibrarySearch(widget.catalog);
  late final _preferences = DuaPreferences(widget.catalog);
  final _query = TextEditingController();
  final _scroll = ScrollController();
  String? _category, _grade;
  final _tags = <String>{};
  String _view = 'all';
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _preferences.load();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _preferences.dispose();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _search(String value) {
    _query.text = value;
    setState(() {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _tag(String value) {
    setState(() {
      _query.clear();
      _tags.clear();
      _tags.add(value);
      _category = null;
      _grade = null;
      _view = 'all';
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _clear() => setState(() {
    _category = null;
    _grade = null;
    _tags.clear();
    _query.clear();
    _view = 'all';
  });

  Future<void> _filters(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DuaStyle(
      child: StatefulBuilder(
        builder: (context, updateSheet) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                dl(context, 'Source type', 'نوع المصدر'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final grade in ['all', 'quran', 'sahih', 'hasan'])
                    ChoiceChip(
                      key: ValueKey('filter-$grade'),
                      label: Text(_gradeName(context, grade)),
                      selected: (_grade ?? 'all') == grade,
                      onSelected: (_) {
                        setState(() => _grade = grade == 'all' ? null : grade);
                        updateSheet(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                dl(
                  context,
                  'Tags • match any selected tag',
                  'الوسوم • مطابقة أي وسم مختار',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final tag in widget.catalog.tags.entries)
                    FilterChip(
                      key: ValueKey('filter-tag-${tag.key}'),
                      label: Text(dt(context, tag.value)),
                      selected: _tags.contains(tag.key),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _tags.add(tag.key);
                          } else {
                            _tags.remove(tag.key);
                          }
                        });
                        updateSheet(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(dl(context, 'Show results', 'عرض النتائج')),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  String _gradeName(BuildContext context, String grade) => switch (grade) {
    'quran' => dl(context, 'Qur’an', 'القرآن'),
    'sahih' => dl(context, 'Sahih', 'صحيح'),
    'hasan' => dl(context, 'Hasan', 'حسن'),
    _ => dl(context, 'All sources', 'كل المصادر'),
  };

  String? _situationNote(BuildContext context, String? situation) {
    if (['phone', 'home', 'purchase', 'car'].contains(situation)) {
      return dl(
        context,
        'We have not verified a specific supplication for this purchase in our collection. Choose the situation below. Gratitude prayers are general; clothing and travel prayers retain their own reported contexts.',
        'لم نتحقق من دعاء خاص بهذه المشتريات في مجموعتنا. اختر الحالة أدناه. أدعية الشكر عامة؛ وأدعية الملابس والسفر تبقى في سياقها الوارد.',
      );
    }
    if (['exam', 'job'].contains(situation)) {
      return dl(
        context,
        'General supplications relevant to this need—not a special exam or interview formula, and not a guarantee of success.',
        'أدعية عامة ذات صلة، وليست صيغة خاصة للامتحان أو مقابلة العمل ولا ضمانًا للنجاح.',
      );
    }
    if (situation == 'sleep') {
      return dl(
        context,
        'No insomnia-specific formula has been checked in this pilot. You can browse the existing Azkar separately; this does not certify that collection.',
        'لم تُراجع صيغة خاصة بالأرق في هذه المجموعة التجريبية. يمكنك تصفح الأذكار الموجودة بصورة منفصلة؛ هذا لا يُعد توثيقًا لتلك المجموعة.',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => DuaStyle(
    child: Builder(
      builder: (context) => AnimatedBuilder(
        animation: _preferences,
        builder: (context, _) {
          final c = widget.catalog;
          final result = _engine.search(
            _query.text,
            category: _category,
            tags: _tags,
            grade: _grade,
            onlyIds: _view == 'favourites'
                ? _preferences.favourites
                : _view == 'recent'
                ? _preferences.recent.toSet()
                : null,
          );
          final entries = [...result.entries];
          if (_view == 'recent') {
            entries.sort(
              (a, b) => _preferences.recent
                  .indexOf(a.id)
                  .compareTo(_preferences.recent.indexOf(b.id)),
            );
          }
          final note = _situationNote(context, result.situation);
          return Scaffold(
            appBar: AppBar(
              title: Text(dl(context, 'Duaa', 'الدعاء')),
              actions: [
                IconButton(
                  tooltip: dl(context, 'Library sources', 'مصادر المكتبة'),
                  icon: const Icon(Icons.menu_book_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DuaSourceIndex(catalog: c),
                    ),
                  ),
                ),
              ],
            ),
            body: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: ListView(
                          controller: _scroll,
                          key: const PageStorageKey('duaa-library'),
                          padding: const EdgeInsets.all(20),
                          children: [
                            Text(
                              dl(
                                context,
                                'Find words for your moment',
                                'لكل موقف دعاء',
                              ),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const ValueKey('duaa-search'),
                              controller: _query,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: dl(
                                  context,
                                  'What do you need duaa for?',
                                  'عمّ تبحث من الدعاء؟',
                                ),
                                hintText: dl(
                                  context,
                                  'New clothes, worry, travel…',
                                  'ملابس جديدة، هم، سفر…',
                                ),
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _query.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: dl(
                                          context,
                                          'Clear search',
                                          'مسح البحث',
                                        ),
                                        onPressed: () => _search(''),
                                        icon: const Icon(Icons.close),
                                      ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final item in [
                                  ('all', 'All', 'الكل'),
                                  ('favourites', 'Favourites', 'المفضلة'),
                                  ('recent', 'Recent', 'الأخيرة'),
                                ])
                                  ChoiceChip(
                                    key: ValueKey('duaa-view-${item.$1}'),
                                    label: Text(dl(context, item.$2, item.$3)),
                                    selected: _view == item.$1,
                                    onSelected: (_) =>
                                        setState(() => _view = item.$1),
                                  ),
                              ],
                            ),
                            if (_view == 'recent')
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton(
                                  onPressed: _preferences.clearRecent,
                                  child: Text(
                                    dl(
                                      context,
                                      'Clear recently opened',
                                      'مسح العناصر الأخيرة',
                                    ),
                                  ),
                                ),
                              ),
                            if (_preferences.error)
                              DuaNotice(
                                text: dl(
                                  context,
                                  'Preferences could not be restored or saved.',
                                  'تعذر استعادة التفضيلات أو حفظها.',
                                ),
                              ),
                            if (_query.text.isEmpty &&
                                _category == null &&
                                _tags.isEmpty)
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final item in [
                                    (
                                      'new purchase',
                                      'New purchase',
                                      'مشتريات جديدة',
                                    ),
                                    (
                                      'worried',
                                      'Feeling worried',
                                      'أشعر بالهم',
                                    ),
                                    ('travel', 'Travelling', 'مسافر'),
                                  ])
                                    ActionChip(
                                      label: Text(
                                        dl(context, item.$2, item.$3),
                                      ),
                                      onPressed: () => _search(item.$1),
                                    ),
                                ],
                              ),
                            ExpansionTile(
                              key: const PageStorageKey('duaa-categories'),
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                _category == null
                                    ? dl(
                                        context,
                                        'Browse categories',
                                        'تصفح الأقسام',
                                      )
                                    : dt(context, c.categories[_category]!),
                              ),
                              leading: const Icon(Icons.grid_view_outlined),
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final wide =
                                        constraints.maxWidth >= 600 &&
                                        MediaQuery.textScalerOf(
                                              context,
                                            ).scale(14) <
                                            24;
                                    return Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final item in c.categories.entries)
                                          SizedBox(
                                            width: wide
                                                ? (constraints.maxWidth - 16) /
                                                      3
                                                : constraints.maxWidth,
                                            child: ListTile(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              selected: _category == item.key,
                                              leading: Icon(
                                                duaCategoryIcons[item.key],
                                              ),
                                              title: Text(
                                                dt(context, item.value),
                                              ),
                                              onTap: () => setState(
                                                () => _category =
                                                    _category == item.key
                                                    ? null
                                                    : item.key,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  key: const ValueKey('duaa-filters'),
                                  onPressed: () => _filters(context),
                                  icon: const Icon(Icons.tune),
                                  label: Text(
                                    dl(
                                      context,
                                      'Tags & sources',
                                      'الوسوم والمصادر',
                                    ),
                                  ),
                                ),
                                if (_category != null)
                                  InputChip(
                                    label: Text(
                                      dt(context, c.categories[_category]!),
                                    ),
                                    onDeleted: () =>
                                        setState(() => _category = null),
                                  ),
                                if (_grade != null)
                                  InputChip(
                                    label: Text(_gradeName(context, _grade!)),
                                    onDeleted: () =>
                                        setState(() => _grade = null),
                                  ),
                                for (final tag in _tags)
                                  InputChip(
                                    label: Text(dt(context, c.tags[tag]!)),
                                    onDeleted: () =>
                                        setState(() => _tags.remove(tag)),
                                  ),
                                if (_query.text.isNotEmpty ||
                                    _category != null ||
                                    _grade != null ||
                                    _tags.isNotEmpty)
                                  TextButton(
                                    onPressed: _clear,
                                    child: Text(
                                      dl(context, 'Clear all', 'مسح الكل'),
                                    ),
                                  ),
                              ],
                            ),
                            if (note != null) DuaNotice(text: note),
                            if ([
                              'phone',
                              'car',
                              'home',
                              'purchase',
                            ].contains(result.situation))
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final item in [
                                    ('new clothes', 'Clothes', 'ملابس'),
                                    ('new car', 'Vehicle', 'سيارة'),
                                    ('new home', 'Home', 'منزل'),
                                    ('gratitude', 'Gratitude', 'شكر'),
                                  ])
                                    ActionChip(
                                      label: Text(
                                        dl(context, item.$2, item.$3),
                                      ),
                                      onPressed: () => _search(item.$1),
                                    ),
                                ],
                              ),
                            if (result.destination != null)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.open_in_new),
                                label: Text(
                                  result.destination == 'azkar'
                                      ? dl(
                                          context,
                                          'Open existing Azkar (separate collection)',
                                          'فتح الأذكار الموجودة (مجموعة منفصلة)',
                                        )
                                      : result.destination == 'hajj'
                                      ? dl(
                                          context,
                                          'Open Hajj guide',
                                          'فتح دليل الحج',
                                        )
                                      : dl(
                                          context,
                                          'Open Umrah guide',
                                          'فتح دليل العمرة',
                                        ),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        result.destination == 'azkar'
                                        ? const AzkarPageClass()
                                        : PilgrimageJourneyPage(
                                            hajj: result.destination == 'hajj',
                                          ),
                                  ),
                                ),
                              ),
                            if (result.suggestion != null)
                              TextButton(
                                onPressed: () => _search(result.suggestion!),
                                child: Text(
                                  dl(
                                    context,
                                    'Did you mean “${result.suggestion}”?',
                                    'هل تقصد «${result.suggestion}»؟',
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              dl(
                                context,
                                '${entries.length} results',
                                '${entries.length} نتيجة',
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (entries.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  dl(
                                    context,
                                    'No matching entries. Try a different phrase or clear your filters.',
                                    'لا توجد نتائج مطابقة. جرّب عبارة أخرى أو امسح عوامل التصفية.',
                                  ),
                                ),
                              ),
                            for (final e in entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Card(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        ListTile(
                                          key: ValueKey('duaa-entry-${e.id}'),
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                            duaCategoryIcons[e.category],
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          title: Text(
                                            dt(context, e.title),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          subtitle: Text(
                                            '${duaOriginLabel(context, e, c)} · ${e.applicability == 'reportedOccasion' ? dl(context, 'Reported occasion', 'مناسبة واردة') : dl(context, 'General duaa', 'دعاء عام')}',
                                          ),
                                          trailing: IconButton(
                                            tooltip: dl(
                                              context,
                                              'Toggle favourite',
                                              'تغيير المفضلة',
                                            ),
                                            onPressed: () =>
                                                _preferences.toggle(e.id),
                                            icon: Icon(
                                              _preferences.favourites.contains(
                                                    e.id,
                                                  )
                                                  ? Icons.bookmark
                                                  : Icons.bookmark_border,
                                            ),
                                          ),
                                          onTap: () {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            _preferences.opened(e.id);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) => DuaReader(
                                                  entry: e,
                                                  catalog: c,
                                                  preferences: _preferences,
                                                  onTag: _tag,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        Text(
                                          dt(context, e.guidance),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          children: [
                                            for (final tag in e.tags.take(3))
                                              ActionChip(
                                                label: Text(
                                                  dt(context, c.tags[tag]!),
                                                ),
                                                onPressed: () => _tag(tag),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              dl(
                                context,
                                'Offline reading and search. Recent items stay on this device; search queries are not saved.',
                                'قراءة وبحث دون إنترنت. العناصر الأخيرة محلية؛ عبارات البحث لا تُحفظ.',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
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
