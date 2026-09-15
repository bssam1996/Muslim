# Biography library

The home navigation panel opens authors, then each author's full book and summary.
`biography_catalog.dart` defines authors, translation keys, stable book IDs,
repository directories, filenames and approximate download sizes. Add entries
there and the matching keys in both `assets/translations` JSON files when adding
authors or books. PDFs stay in `Books/` and must not be added to Flutter assets.

Downloads use the raw GitHub URLs on `main`. Re-download requests bypass cached
URLs, validate the complete PDF, and replace the saved copy only after success.
An interrupted or invalid replacement leaves the previous copy available.
Native platforms stream to application support storage; web uses Cache Storage
(HTTPS or localhost), which browsers may evict or users may clear. The UI handles
unavailable storage and failed downloads. Leaving the book list cancels an active
download; downloads do not run as background tasks.

The reader supports zoom, page navigation, separate saved reading positions and
multiple page bookmarks for each book. Use the bookmark icon to save/remove the
current page and the bookmarks list to return to saved pages after reopening.
Bookmarks persist across re-downloads. Pages absent from a shorter updated edition
remain listed for removal but cannot be opened. The last reading position is
clamped to the updated document's page count.
Arabic and English translations cover the UI; the PDFs retain their original
content and language. The PDF engine adds its own platform binaries, but adding
more remote books does not add PDF bytes to the installed app.

Validation:

```sh
flutter test test/biography_download_test.dart test/biography_ui_test.dart test/biography_pdf_test.dart test/biography_bookmarks_test.dart
flutter test --platform chrome test/biography_storage_web_test.dart
flutter analyze lib/UI/biographies
flutter build web --release
flutter build apk --debug
```

The PDF tests open the repository copies and render their first and last pages.
