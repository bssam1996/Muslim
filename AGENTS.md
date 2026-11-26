# Repository Guidelines

## Project Structure & Module Organization

This Flutter/Dart Islamic companion primarily targets Android, with limited web support. `lib/main.dart` initializes localization, appearance, and platform services; `lib/home_page.dart` hosts the home screen.

- `lib/UI/`: feature screens, including prayer notifications, Quran, Dua, Azkar, and book readers.
- `lib/shared/`: reusable widgets, navigation, responsive layout, and theming.
- `lib/utils/`: networking, caching, preferences, prayer scheduling, and notifications.
- `assets/`: images, fonts, audio, catalogs, and `translations/{en-US,ar-EG}.json`.
- `test/`: unit and widget tests; shared helpers in `test/support/` and data in `test/fixtures/`.
- `Books/`: downloadable PDF sources; `tool/`: catalog and inventory utilities.
- `android/`, `web/`, and other platform directories: native integration and packaging.

## Build, Test, and Development Commands

Use a Flutter SDK compatible with the Dart constraint in `pubspec.yaml` (`>=3.10.0 <4.0.0`). Run commands from the repository root:

- `flutter pub get`: install dependencies.
- `flutter run`: launch on a connected device or emulator.
- `flutter run -d chrome`: launch the web app.
- `dart format lib test`: format Dart sources and tests.
- `flutter analyze`: run static analysis using `flutter_lints`.
- `flutter test`: run the test suite.
- `flutter test --platform chrome test/biography_storage_web_test.dart`: verify browser storage.
- `flutter build apk --debug` / `flutter build web --release`: build Android or web artifacts.

## Coding Style & Naming Conventions

Use two-space indentation and Dart formatter output. Name files `lower_snake_case.dart`, types `UpperCamelCase`, and members `lowerCamelCase`; prefix private members with `_`. Preserve the existing `lib/UI/` capitalization. Keep feature code together and reuse shared widgets and services. Add UI translation keys to both locale files, preserving Arabic text and right-to-left behavior.

## Testing Guidelines

Use `flutter_test`, descriptive `test`/`testWidgets` names, and filenames ending in `_test.dart`. Add regression coverage for changed behavior; mock network, preferences, and platform services using existing patterns. Run focused tests during development, then the suite before review. No numeric coverage threshold is configured.

## Commit & Pull Request Guidelines

History uses short descriptive subjects such as `Adding prophets logic`; no strict prefix convention is evident. Keep commits focused. PRs should explain behavior changes, link relevant issues, list validation commands and results, and include screenshots for UI changes.

## Content & Configuration

Register bundled assets in `pubspec.yaml`; keep PDFs in `Books/` rather than Flutter assets. Edit `Books/Prophets/sources.json`, then regenerate inventory with `python tool/verify_prophet_books.py`; follow the feature README. Preserve stable book IDs and preference keys. Never commit signing keys or build artifacts.
