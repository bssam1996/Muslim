import '../books/library_book.dart';
import 'prophet_book_inventory.dart';

enum ProphetStoryKind { kids, full }

enum LifespanStatus { established, approximate, disputed, unknown }

enum ProphetSummaryKind { miracle, storyHighlight }

class ProphetSourceReference {
  const ProphetSourceReference({required this.reference, required this.url});
  final String reference;
  final String url;
}

class ProphetLifespan {
  const ProphetLifespan({
    this.years,
    this.status = LifespanStatus.unknown,
    this.sourceReference,
    this.noteKey,
    this.yearBasis,
  }) : assert(
         (years == null && status == LifespanStatus.unknown) ||
             (years != null &&
                 years > 0 &&
                 status != LifespanStatus.unknown &&
                 sourceReference != null),
       );

  final int? years;
  final LifespanStatus status;
  final ProphetSourceReference? sourceReference;
  final String? noteKey;
  final String? yearBasis;
}

class ProphetSummary {
  const ProphetSummary({
    required this.kind,
    required this.descriptionKey,
    required this.sourceReference,
  });
  final ProphetSummaryKind kind;
  final String descriptionKey;
  final ProphetSourceReference sourceReference;
}

class ProphetStorySlot {
  const ProphetStorySlot({required this.kind, required this.editions});
  final ProphetStoryKind kind;
  final List<LibraryBook> editions;
  String get titleKey => kind == ProphetStoryKind.kids
      ? 'Prophets_Kids_Story'
      : 'Prophets_Full_Story';
  LibraryBookSlot get librarySlot =>
      LibraryBookSlot(titleKey: titleKey, editions: editions);
}

class Prophet {
  const Prophet({
    required this.id,
    required this.chronologicalOrder,
    required this.sourceReference,
    required this.lifespan,
    required this.miracleSummary,
    required this.stories,
  });

  final String id;
  final int chronologicalOrder;
  final ProphetSourceReference sourceReference;
  final ProphetLifespan lifespan;
  final ProphetSummary? miracleSummary;
  final List<ProphetStorySlot> stories;
  String get nameKey => 'Prophets_Name_$id';
  String get imageAsset => 'assets/prophets/$id/pic.png';
  String get imageCaptionKey => 'Prophets_Caption_$id';
}

// Approximate editorial chronology, not a dated timeline. The Quran establishes
// some relationships; Ibn Kathir's published accounts guide the wider sequence.
// Relative placement of Idris, Ayyub, Shuayb, Dhul-Kifl and Yunus is uncertain.
// The list page exposes this qualification and the source offline.
const prophetChronologySource = ProphetSourceReference(
  reference:
      'Ibn Kathir, Qasas al-Anbiya; Quran 7:59-93, 11:71, 12:4-6, 19:7-34',
  url: 'https://islamhouse.com/en/books/2430/',
);

final List<Prophet> prophetCatalog = buildProphetCatalog();

List<Prophet> buildProphetCatalog() {
  const order = [
    'adam',
    'idris',
    'nuh',
    'hud',
    'salih',
    'ibrahim',
    'lut',
    'ismail',
    'ishaq',
    'yaqub',
    'yusuf',
    'shuayb',
    'ayyub',
    'dhul_kifl',
    'musa',
    'harun',
    'dawud',
    'sulayman',
    'ilyas',
    'al_yasa',
    'yunus',
    'zakariya',
    'yahya',
    'isa',
    'muhammad',
  ];
  const passages = {
    'adam': '2:31',
    'idris': '19:56-57',
    'nuh': '11:37-44',
    'hud': '11:58',
    'salih': '7:73',
    'ibrahim': '21:69',
    'lut': '11:81',
    'ismail': '2:127',
    'ishaq': '11:71',
    'yaqub': '12:96',
    'yusuf': '12:4-6',
    'shuayb': '7:85',
    'ayyub': '38:41-44',
    'dhul_kifl': '21:85-86',
    'musa': '26:63',
    'harun': '20:29-32',
    'dawud': '34:10-11',
    'sulayman': '27:16-19',
    'ilyas': '37:123-126',
    'al_yasa': '38:48',
    'yunus': '21:87-88',
    'zakariya': '19:7-9',
    'yahya': '19:12-15',
    'isa': '3:49',
    'muhammad': '17:1',
  };
  const miracleIds = {
    'salih',
    'ibrahim',
    'yaqub',
    'ayyub',
    'musa',
    'dawud',
    'sulayman',
    'yunus',
    'zakariya',
    'isa',
    'muhammad',
    'ismail',
  };
  return List.unmodifiable([
    for (var index = 0; index < order.length; index++)
      _entry(
        order[index],
        index + 1,
        passages[order[index]]!,
        miracleIds.contains(order[index]),
      ),
  ]);
}

Prophet _entry(String id, int order, String passage, bool miracle) {
  final parts = passage.split(':');
  final source = id == 'ismail'
      ? const ProphetSourceReference(
          reference: 'Sahih al-Bukhari 3364',
          url: 'https://sunnah.com/bukhari:3364',
        )
      : ProphetSourceReference(
          reference: 'Quran $passage',
          url: 'https://quran.com/${parts[0]}/${parts[1]}',
        );
  final ProphetLifespan lifespan;
  if (id == 'muhammad') {
    lifespan = const ProphetLifespan(
      years: 63,
      status: LifespanStatus.established,
      sourceReference: ProphetSourceReference(
        reference: 'Sahih al-Bukhari 3902',
        url: 'https://sunnah.com/bukhari:3902',
      ),
      noteKey: 'Prophets_Lifespan_Muhammad_Note',
    );
  } else if (id == 'nuh') {
    lifespan = const ProphetLifespan(
      sourceReference: ProphetSourceReference(
        reference: 'Quran 29:14',
        url: 'https://quran.com/29/14',
      ),
      noteKey: 'Prophets_Lifespan_Nuh_Note',
    );
  } else {
    lifespan = const ProphetLifespan(noteKey: 'Prophets_Lifespan_Unknown_Note');
  }
  return Prophet(
    id: id,
    chronologicalOrder: order,
    sourceReference: source,
    lifespan: lifespan,
    miracleSummary: ProphetSummary(
      kind: miracle
          ? ProphetSummaryKind.miracle
          : ProphetSummaryKind.storyHighlight,
      descriptionKey: 'Prophets_Summary_$id',
      sourceReference: source,
    ),
    stories: List.unmodifiable([
      for (final kind in ProphetStoryKind.values)
        ProphetStorySlot(
          kind: kind,
          editions: List.unmodifiable(
            prophetBookInventory.where(
              (book) => book.id.startsWith('prophet_${id}_${kind.name}_'),
            ),
          ),
        ),
    ]),
  );
}
