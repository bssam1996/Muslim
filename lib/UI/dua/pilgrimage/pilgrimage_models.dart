/// Bilingual religious content is stored alongside its references so the two
/// languages and both navigation views always use the same evidence.
class PilgrimageText {
  const PilgrimageText(this.en, this.ar);
  final String en;
  final String ar;
  String resolve(bool arabic) => arabic ? ar : en;
}

enum ContentKind { riteDhikr, generalDua, instruction }

enum Landmark {
  kaaba,
  hills,
  tents,
  mountain,
  night,
  pillars,
  sacrifice,
  scissors,
  ihram,
}

enum HajjType { overview, tamattu, qiran, ifrad }

class PilgrimageSource {
  const PilgrimageSource(this.id, this.title, this.status, this.url);
  final String id;
  final PilgrimageText title;

  /// Includes the collection/authority; Qur'an and scholarly guidance are
  /// explicitly distinguished from graded hadith.
  final PilgrimageText status;
  final String url;
}

class PilgrimageContent {
  const PilgrimageContent({
    required this.id,
    required this.title,
    required this.kind,
    required this.guidance,
    required this.sources,
    this.action,
    this.arabic = '',
    this.meaning = '',
    this.transliteration = '',
  });
  final String id;
  final PilgrimageText title;
  final ContentKind kind;
  final PilgrimageText guidance;

  /// A concise action, displayed prominently rather than as a duaa title.
  final PilgrimageText? action;
  final String arabic;

  /// Original English rendering of the Arabic, not a copied site translation.
  final String meaning;
  final String transliteration;
  final List<PilgrimageSource> sources;
}

class PilgrimageStep {
  const PilgrimageStep({
    required this.id,
    required this.title,
    required this.stage,
    required this.landmark,
    required this.content,
    this.condition,
    this.sources = const [],
  });
  final String id;
  final PilgrimageText title;
  final PilgrimageText stage;
  final Landmark landmark;
  final List<PilgrimageContent> content;
  final PilgrimageText? condition;
  final List<PilgrimageSource> sources;

  Iterable<String> get searchTerms => [
    title.en,
    title.ar,
    stage.en,
    stage.ar,
    if (condition != null) condition!.en,
    if (condition != null) condition!.ar,
    for (final item in content) ...[
      item.title.en,
      item.title.ar,
      item.arabic,
      item.meaning,
      item.transliteration,
      item.guidance.en,
      item.guidance.ar,
      if (item.action != null) item.action!.en,
      if (item.action != null) item.action!.ar,
    ],
  ];
}

List<PilgrimageSource> sourcesForSteps(Iterable<PilgrimageStep> steps) {
  final unique = <String, PilgrimageSource>{};
  for (final step in steps) {
    for (final source in [
      ...step.sources,
      ...step.content.expand((c) => c.sources),
    ]) {
      unique[source.id] = source;
    }
  }
  return List.unmodifiable(unique.values);
}
