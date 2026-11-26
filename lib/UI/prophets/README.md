# Prophets library

The home activities grid and navigation panel open `ProphetsPage`. Each prophet
has two story slots, Kids Story and Full Story, using the shared book controls in
`lib/UI/books/`. Reader positions and bookmarks use the stable edition IDs.
The biography compatibility exports, original book IDs, preference keys, native
directory and browser cache keys remain unchanged.

## PDFs and publication

`Books/Prophets/sources.json` is the source inventory. There are 92 supplied PDFs:
25 Arabic kids editions, 17 English kids editions and 50 adult editions. Eight
English kids editions are absent; those kids cards offer their supplied Arabic
edition and explicitly label its language. Each story card with multiple editions
has a PDF language selector, independent of the app language and the other card.
The initial choice prefers the app language when available. Users can download
both versions; switching the selector shows that version's download status,
Read, Re-download and Delete controls. Downloads, bookmarks and reading positions
remain separate by edition ID. Selectors are disabled during a book operation
so the active download and its Cancel control stay visible.
Source filenames use capital letters
and some differ from the artwork IDs: Saleh/salih, Shuayyb/shuayb,
Sulaiman/sulayman, Zakariyya/zakariya, Al-Yasa/al_yasa, Dhul-Kifl/dhul_kifl.
The inventory generator preserves these exact paths.

Publication check on 2026-10-05 after the Books merge: all 92 raw GitHub PDFs
matched the complete local files, including their SHA-256 hashes. The generated
inventory enables every supplied edition with `available: true`. Unverified
future editions show Coming soon; previously saved copies remain readable.

After adding or replacing PDFs on `bssam1996/Muslim`, branch `main`, run:

```powershell
python tool/verify_prophet_books.py
dart format lib/UI/prophets/prophet_book_inventory.dart
flutter test test/prophet_catalog_test.dart test/prophets_ui_test.dart
```

The verifier fetches each entire remote PDF, checks its size, signature, EOF and
SHA-256 against the reviewed local edition, and enables only exact matches.
Commit its status file and generated inventory with the app changes. The
`--offline` option regenerates metadata while preserving successful verification
for unchanged hashes. Changed editions must be verified again. Replace a book
at the same path, update `sources.json`, and retain its stable ID; installed users
can use Re-download. Do not add PDFs to `pubspec.yaml`.

## Content and illustrations

`prophet_catalog.dart` defines the explicit approximate historical sequence,
source references, structured lifespan metadata and miracle/story-highlight
classification. The chronology is editorial and qualified in both languages;
do not treat the relative placement of Idris, Shuayb, Ayyub, Dhul-Kifl or Yunus as
settled dates. Its source is Ibn Kathir's Qasas al-Anbiya, supported by Quranic
family relationships and narratives.

The current lifespan review includes Muhammad's age 63 from Sahih al-Bukhari
3902. Other total lifespans remain unknown. Quran 29:14 describes Nuh's 950 years
among his people, not his total lifespan. Displayed estimates or disputed reports
must have an explicit source and qualification; no number is inferred from a
PDF's narrative. Lifespan context and every summary's reference are available
offline in source sheets; opening their website is optional.

Each summary and caption has Arabic and English translations. The content matrix
below documents the association; captions for symbolic artwork avoid claiming
that decorative staffs, landscapes, flowers or books are sourced miracles.

| ID | Illustration association / summary source | Kind |
| --- | --- | --- |
| adam | Knowledge as Allah's gift; Quran 2:31 | Story highlight |
| idris | Truthfulness and elevation; Quran 19:56-57 | Story highlight |
| nuh | Ark and rescue; Quran 11:37-44 | Story highlight |
| hud | Rescue by Allah's mercy; Quran 11:58 | Story highlight |
| salih | She-camel as a sign; Quran 7:73 | Miracle |
| ibrahim | Fire made cool and safe; Quran 21:69 | Miracle |
| lut | Departure before punishment; Quran 11:81 | Story highlight |
| ismail | Zamzam spring; Sahih al-Bukhari 3364 | Miracle |
| ishaq | Good news of Ishaq and Yaqub; Quran 11:71 | Story highlight |
| yaqub | Return of sight with Yusuf's shirt; Quran 12:96 | Miracle |
| yusuf | Dream of stars, sun and moon; Quran 12:4-6 | Story highlight |
| shuayb | Fair measures and rights; Quran 7:85 | Story highlight |
| ayyub | Cool water for washing and drinking; Quran 38:41-44 | Miracle |
| dhul_kifl | Patience and righteousness; Quran 21:85-86 | Story highlight |
| musa | Sea divided; Quran 26:63 | Miracle |
| harun | Musa's helper; Quran 20:29-32 | Story highlight |
| dawud | Iron softened; Quran 34:10-11 | Miracle |
| sulayman | Language of birds and an ant; Quran 27:16-19 | Miracle |
| ilyas | Calling people to worship Allah; Quran 37:123-126 | Story highlight |
| al_yasa | Counted among the excellent; Quran 38:48 | Story highlight |
| yunus | Prayer answered and rescue; Quran 21:87-88 | Miracle |
| zakariya | Good news of Yahya in old age; Quran 19:7-9 | Miracle |
| yahya | Wisdom in childhood and care for parents; Quran 19:12-15 | Story highlight |
| isa | Bird from clay by Allah's permission; Quran 3:49 | Miracle |
| muhammad | Night Journey; Quran 17:1 | Miracle |

The supplied 300-pixel illustrations stay in `assets/prophets/<id>/pic.png`.
Reuse them on the list, header and fixed faint decoration. A radial alpha mask
feathers the decoration so the supplied opaque square images do not leave a
solid rectangular background. Decorations ignore pointer events and semantics;
failed assets have neutral fallbacks. The generated transparent home icon is
`assets/prophets/prophets.png` and contains scenery and objects only.

## Checks

```powershell
flutter analyze lib/UI/books lib/UI/prophets lib/UI/biographies
flutter test test/prophet_catalog_test.dart test/prophets_ui_test.dart
flutter test test/biography_download_test.dart test/biography_ui_test.dart test/biography_pdf_test.dart test/biography_bookmarks_test.dart
flutter test --platform chrome test/biography_storage_web_test.dart
flutter build web --release
flutter build apk --debug
```

Catalogue checks cover all 25 IDs, 92 PDF paths, artwork registration, source
requirements, language selection and bilingual placeholders. Widget checks cover
all prophet routes in both languages, restored list position, large text, offline
source context, coming-soon slots and the shared download/validation controls.
Language checks cover an English app downloading Arabic PDFs and an Arabic app
downloading English PDFs, both languages saved simultaneously, independent story
choices, deletion of only the selected version, and large text in both layouts.

Validation of the current update on this Windows machine passed 67 focused
tests, feature analysis, the web release build and the Android debug build.
The earlier Chrome cache-storage regression also passed.
Android validation used a temporary 4 GB Gradle heap and two workers to avoid
the existing 1.5 GB heap limit during Jetifier transforms. No Gradle settings
were changed. Flutter 3.44.8's Windows test server returned 404 for its local
CanvasKit assets; the Chrome check passed using a browser-only route that served
the same installed SDK files. No Flutter SDK files were changed.

The current built web app was also checked in Chrome at a 390-pixel width in
English and Arabic: Home -> Prophets -> Adam -> Full Story. In each app language,
both real published Arabic and English PDFs downloaded and were cached under
separate IDs. After switching back to the other language, its saved PDF opened
with GitHub requests blocked. There were no browser errors. Download availability
for all supplied editions is backed by all 92 remote hash checks.
