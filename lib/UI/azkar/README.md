# Azkar reader

The Home entry point remains `AzkarPageClass`; callers can still open a
collection directly with `AzkarCardPageClass(keyname: ...)`.

## Responsibilities

- `azkar_page.dart`: category cards, bilingual category search and navigation.
- `azkar_card_page.dart`: focused reading, searchable picker, copy, counter,
  text controls, progress and confirmed restart.
- `azkar_style.dart`: scoped light/dark violet theme, bilingual interface labels
  and native vector icons. No generated bitmap assets or new packages needed.
- `azkar_session.dart`: testable count/position state and serialized local saves.
- `azkar_list.dart` / `azkar_items.dart`: existing religious content, unchanged
  by this visual refactor. The daily-routine screen still uses this collection.

## Session behavior

Counts stay between zero and the existing item's target. Completing a dhikr
does not automatically advance. Undo subtracts one repetition. A confirmed
restart clears only the current collection, retaining the global text size.
Sessions resume explicitly and do not reset at midnight or imply a daily streak.

Preferences use `azkar.session.v1.<category>` and `azkar.fontSize`. Counts and
position are associated with the exact text and target, not a fragile list
index. Reordered items keep their progress; changed items start from zero.
Writes are serialized to preserve the latest count during rapid taps. Storage
errors leave the reader usable and display a warning. No account, remote sync,
location, notification permissions, or analytics are added.

Text size ranges from 20 to 40, defaulting to 28. System text scaling is also
respected, including the picker and reset dialog. Arabic religious text keeps
its RTL direction in either interface language. Descriptions remain expanded
by default because some contain timing instructions.

## Verification

`flutter test test/azkar_test.dart` covers persistence, reset isolation, bounds,
content updates, corrupted storage, search, navigation, completion, copy,
descriptions, and enlarged text/RTL/dark layouts with the keyboard open.

## Suggested next iterations (not implemented)

1. Audit wording, repetition counts and descriptions; add precise source links
   and authenticity notes. This UI work does not certify the existing content.
2. Add optional user-configured morning/evening reminders with quiet hours.
3. Add reviewed translations, transliteration and licensed audio with offline
   downloads for users learning the Arabic.
4. Add personal bookmarks for quick access to frequently read adhkar.
