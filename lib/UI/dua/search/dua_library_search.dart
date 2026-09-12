import '../models/dua_catalog.dart';

String normalizeDua(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
    .replaceAll(RegExp('[إأآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
      final rune = m[0]!.runes.first;
      return '${rune >= 0x6f0 ? rune - 0x6f0 : rune - 0x660}';
    })
    .replaceAll(RegExp(r'[^a-z0-9\u0621-\u064A\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class DuaSearchResult {
  const DuaSearchResult(
    this.entries, {
    this.situation,
    this.suggestion,
    this.destination,
  });
  final List<DuaEntry> entries;
  final String? situation, suggestion, destination;
}

/// Curated discovery aliases only. They never modify a text or establish a rite.
class DuaLibrarySearch {
  DuaLibrarySearch(this.catalog) {
    for (final e in catalog.entries) {
      index[e.id] = normalizeDua(
        [
          e.title.en,
          e.title.ar,
          e.guidance.en,
          e.guidance.ar,
          ...e.aliases,
          for (final tag in e.tags)
            '${catalog.tags[tag]!.en} ${catalog.tags[tag]!.ar}',
          for (final b in e.blocks)
            '${b.arabic} ${b.meaning} ${b.transliteration}',
          for (final source in catalog.sourcesFor([e]))
            '${source.title.en} ${source.title.ar}',
        ].join(' '),
      );
    }
  }
  final DuaCatalog catalog;
  final Map<String, String> index = {};

  static const situations = <String, List<String>>{
    'phone': [
      'new phone',
      'new laptop',
      'اشتريت موبايل',
      'موبايل جديد',
      'اشتريت تليفون',
    ],
    'car': [
      'new car',
      'bought a car',
      'سيارة جديدة',
      'عربية جديدة',
      'اشتريت عربية',
    ],
    'home': [
      'new house',
      'new home',
      'moving house',
      'بيت جديد',
      'شقة جديدة',
      'اشتريت بيت',
    ],
    'clothes': [
      'new shirt',
      'new clothes',
      'new dress',
      'new garment',
      'لبس جديد',
      'ملابس جديدة',
      'ثوب جديد',
      'اشتريت هدوم',
    ],
    'purchase': [
      'bought something new',
      'new purchase',
      'اشتريت حاجة جديدة',
      'اشتريت شيء جديد',
    ],
    'exam': ['exam', 'studying', 'study', 'مذاكرة', 'امتحان'],
    'job': ['job interview', 'interview', 'مقابلة عمل', 'انترفيو'],
    'worry': [
      'worried',
      'worry',
      'anxiety',
      'grief',
      'قلقان',
      'هم وحزن',
      'حزين',
    ],
    'debt': ['debt', 'debts', 'ديون', 'دين'],
    'decision': ['istikhara', 'istikharah', 'decision', 'استخارة', 'اختيار'],
    'sleep': [
      'cannot sleep',
      'can t sleep',
      'insomnia',
      'مش عارف انام',
      'لا استطيع النوم',
    ],
  };
  static const intentEntries = <String, List<String>>{
    'phone': ['gratitude', 'blessings'],
    'home': ['gratitude', 'blessings'],
    'car': ['gratitude', 'blessings', 'travel'],
    'clothes': ['new-garment', 'gratitude'],
    'purchase': ['new-garment', 'gratitude', 'blessings'],
    'exam': ['knowledge', 'all-good'],
    'job': ['provision', 'all-good', 'istikhara'],
    'worry': ['worry', 'yunus', 'steadfast'],
    'debt': ['worry', 'provision'],
    'decision': ['istikhara'],
    'sleep': [],
  };

  DuaSearchResult search(
    String input, {
    String? category,
    Set<String> tags = const {},
    String? grade,
    Set<String>? onlyIds,
  }) {
    final query = normalizeDua(input);
    bool phrase(String value) =>
        ' $query '.contains(' ${normalizeDua(value)} ');
    String? situation;
    for (final item in situations.entries) {
      if (item.value.any(phrase)) {
        situation = item.key;
        break;
      }
    }
    String? destination;
    if (['umrah', 'عمرة'].any(phrase)) {
      destination = 'umrah';
    } else if (['hajj', 'حج'].any(phrase)) {
      destination = 'hajj';
    } else if (situation == 'sleep' ||
        [
          'azkar',
          'adhkar',
          'اذكار',
          'morning',
          'evening',
          'sleep',
          'الصباح',
          'المساء',
          'النوم',
        ].any(phrase)) {
      destination = 'azkar';
    }
    final intent = intentEntries[situation];
    final filler = {
      'i',
      'a',
      'an',
      'the',
      'for',
      'duaa',
      'dua',
      'du',
      'please',
      'need',
      'feel',
      'am',
      'دعاء',
      'ادعية',
      'اريد',
    };
    final tokens = query
        .split(' ')
        .where((t) => t.isNotEmpty && !filler.contains(t))
        .toList();
    final scored = <(DuaEntry, int)>[];
    for (final e in catalog.entries) {
      if (category != null && e.category != category) continue;
      if (tags.isNotEmpty && !e.tags.any(tags.contains)) continue;
      if (grade != null &&
          !e.sourceIds.any((id) => catalog.sources[id]!.grade == grade)) {
        continue;
      }
      if (onlyIds != null && !onlyIds.contains(e.id)) continue;
      int score = 1;
      if (query.isNotEmpty) {
        if (intent != null) {
          final rank = intent.indexOf(e.id);
          if (rank < 0) continue;
          score = 1000 - rank;
        } else {
          if (tokens.isEmpty || !tokens.every(index[e.id]!.contains)) continue;
          final title = normalizeDua('${e.title.en} ${e.title.ar}');
          score = e.aliases.any((a) => normalizeDua(a) == query)
              ? 1000
              : title.contains(query)
              ? 900
              : tokens.every(title.contains)
              ? 800
              : 100;
        }
      }
      scored.add((e, score));
    }
    scored.sort(
      (a, b) => b.$2.compareTo(a.$2) != 0
          ? b.$2.compareTo(a.$2)
          : a.$1.id.compareTo(b.$1.id),
    );
    String? suggestion;
    if (scored.isEmpty &&
        query.length >= 4 &&
        !query.contains(' ') &&
        situation == null) {
      for (final alias in catalog.entries.expand((e) => e.aliases)) {
        final normalized = normalizeDua(alias);
        if (_oneEdit(query, normalized)) {
          suggestion = alias;
          break;
        }
      }
    }
    return DuaSearchResult(
      List.unmodifiable(scored.map((s) => s.$1)),
      situation: situation,
      suggestion: suggestion,
      destination: destination,
    );
  }

  static bool _oneEdit(String a, String b) {
    if ((a.length - b.length).abs() > 1 || a == b) return false;
    var i = 0, j = 0, edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length >= b.length) i++;
      if (b.length >= a.length) j++;
    }
    return edits + (a.length - i) + (b.length - j) == 1;
  }
}
