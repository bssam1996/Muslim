import 'dart:convert';

class DuaText {
  const DuaText(this.en, this.ar);
  final String en, ar;
  String resolve(bool arabic) => arabic ? ar : en;
  factory DuaText.parse(dynamic value) {
    final map = value as Map<String, dynamic>;
    return DuaText(map['en'] as String, map['ar'] as String);
  }
}

class DuaSource {
  DuaSource(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = DuaText.parse(json['title']),
      grade = json['grade'] as String,
      authority = DuaText.parse(json['authority']),
      url = json['url'] as String,
      narrator = DuaText.parse(json['narrator']);
  final String id, grade, url;
  final DuaText title, authority, narrator;
}

class DuaBlock {
  DuaBlock(Map<String, dynamic> json)
    : id = json['id'] as String,
      arabic = json['arabic'] as String,
      meaning = json['meaning'] as String,
      transliteration = json['transliteration'] as String? ?? '',
      repeat = json['repeat'] as int?,
      sourceIds = List<String>.unmodifiable(json['sources'] as List);
  final String id, arabic, meaning, transliteration;
  final int? repeat;
  final List<String> sourceIds;
}

class DuaEntry {
  DuaEntry(Map<String, dynamic> json)
    : id = json['id'] as String,
      version = json['version'] as int,
      title = DuaText.parse(json['title']),
      guidance = DuaText.parse(json['guidance']),
      category = json['category'] as String,
      origin = json['origin'] as String,
      applicability = json['applicability'] as String,
      tags = List<String>.unmodifiable(json['tags'] as List),
      aliases = List<String>.unmodifiable(json['aliases'] as List),
      related = List<String>.unmodifiable(json['related'] as List),
      blocks = List<DuaBlock>.unmodifiable(
        (json['blocks'] as List).map((b) => DuaBlock(b)),
      ),
      review = Map<String, dynamic>.unmodifiable(
        json['review'] as Map<String, dynamic>,
      );
  final String id, category, origin, applicability;
  final int version;
  final DuaText title, guidance;
  final List<String> tags, aliases, related;
  final List<DuaBlock> blocks;
  final Map<String, dynamic> review;
  bool get published => review['status'] == 'published';
  Iterable<String> get sourceIds => blocks.expand((b) => b.sourceIds).toSet();
  String get arabic => blocks.map((b) => b.arabic).join('\n\n');
}

class DuaCatalog {
  DuaCatalog._(
    this.version,
    this.entries,
    this.sources,
    this.tags,
    this.categories,
    this.redirects,
  );
  final String version;
  final List<DuaEntry> entries;
  final Map<String, DuaSource> sources;
  final Map<String, DuaText> tags, categories;
  final Map<String, String> redirects;

  factory DuaCatalog.decode(String raw, {bool allowPreview = false}) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['schema'] != 1) {
      throw const FormatException('Unsupported Duaa schema');
    }
    final sourceList = (json['sources'] as List)
        .map((s) => DuaSource(s))
        .toList();
    final sources = {for (final source in sourceList) source.id: source};
    if (sources.length != sourceList.length) {
      throw const FormatException('Duplicate source');
    }
    Map<String, DuaText> labels(String key) => Map.unmodifiable(
      (json[key] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, DuaText.parse(v)),
      ),
    );
    final entries = (json['entries'] as List).map((e) => DuaEntry(e)).toList();
    final catalog = DuaCatalog._(
      json['version'] as String,
      List.unmodifiable(entries),
      Map.unmodifiable(sources),
      labels('tags'),
      labels('categories'),
      Map<String, String>.unmodifiable(json['redirects'] as Map),
    );
    catalog.validate(allowPreview: allowPreview);
    return catalog;
  }

  void validate({bool allowPreview = false}) {
    void require(bool valid, String message) {
      if (!valid) throw FormatException(message);
    }

    bool bilingual(DuaText text) =>
        text.en.trim().isNotEmpty && text.ar.trim().isNotEmpty;
    final ids = entries.map((e) => e.id).toSet();
    require(ids.length == entries.length, 'Duplicate entry ID');
    require(
      tags.values.every(bilingual) && categories.values.every(bilingual),
      'Missing labels',
    );
    for (final source in sources.values) {
      final uri = Uri.tryParse(source.url);
      require(
        uri != null && uri.scheme == 'https' && uri.host.isNotEmpty,
        'Invalid source URL',
      );
      require(
        ['quran', 'sahih', 'hasan'].contains(source.grade),
        'Unaccepted grade',
      );
      require(
        bilingual(source.title) &&
            bilingual(source.authority) &&
            bilingual(source.narrator),
        'Incomplete source',
      );
    }
    for (final entry in entries) {
      require(
        entry.version > 0 &&
            bilingual(entry.title) &&
            bilingual(entry.guidance),
        'Incomplete entry',
      );
      require(
        ['quran', 'propheticReport'].contains(entry.origin),
        'Unknown origin',
      );
      require(
        ['reportedOccasion', 'generalRelevance'].contains(entry.applicability),
        'Unknown applicability',
      );
      require(categories.containsKey(entry.category), 'Unknown category');
      require(
        entry.tags.isNotEmpty && entry.tags.every(tags.containsKey),
        'Unknown tags',
      );
      require(entry.related.every(ids.contains), 'Unknown related entry');
      require(entry.blocks.isNotEmpty, 'No recitation');
      require(
        entry.blocks.map((b) => b.id).toSet().length == entry.blocks.length,
        'Duplicate block ID',
      );
      for (final block in entry.blocks) {
        require(
          block.arabic.trim().isNotEmpty && block.meaning.trim().isNotEmpty,
          'Missing text',
        );
        require(
          block.repeat == null || block.repeat! > 0,
          'Invalid repetition',
        );
        require(
          block.sourceIds.isNotEmpty &&
              block.sourceIds.every(sources.containsKey),
          'Missing evidence',
        );
      }
      final review = entry.review;
      require(
        review['sourceCheckedAt'] is String &&
            DateTime.tryParse(review['sourceCheckedAt']) != null &&
            review['rights'] is String &&
            (review['rights'] as String).trim().isNotEmpty,
        'Missing provenance',
      );
      if (!allowPreview || entry.published) {
        require(
          entry.published &&
              review['reviewer'] is String &&
              (review['reviewer'] as String).trim().isNotEmpty &&
              review['approvedVersion'] == entry.version &&
              review['approvedAt'] is String &&
              DateTime.tryParse(review['approvedAt']) != null &&
              review['languageChecked'] == true &&
              review['textChecked'] == true &&
              review['contextChecked'] == true &&
              review['countsChecked'] == true &&
              review['rightsCleared'] == true,
          'Publication requires version-matched editorial approval: ${entry.id}',
        );
      } else {
        require(
          review['status'] == 'sourceChecked',
          'Only source-checked drafts can be previewed',
        );
      }
    }
    for (final oldId in redirects.keys) {
      require(
        !ids.contains(oldId) && ids.contains(redirects[oldId]),
        'Invalid redirect',
      );
    }
  }

  String? resolveId(String id) {
    final resolved = redirects[id] ?? id;
    return entries.any((e) => e.id == resolved) ? resolved : null;
  }

  List<DuaSource> sourcesFor(Iterable<DuaEntry> selected) => [
    for (final id in selected.expand((e) => e.sourceIds).toSet()) sources[id]!,
  ];
}
