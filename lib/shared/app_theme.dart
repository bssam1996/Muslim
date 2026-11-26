import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const small = 8.0;
  static const medium = 12.0;
  static const page = 16.0;
  static const section = 24.0;
  static const radius = 16.0;
}

/// Semantic colors shared by older pages and Material reader controls.
class AppPalette {
  AppPalette(this.scheme);
  final ColorScheme scheme;
  factory AppPalette.of(BuildContext context) =>
      AppPalette(Theme.of(context).colorScheme);
  bool get dark => scheme.brightness == Brightness.dark;
  Color get canvas => scheme.surface;
  Color get panel => scheme.surfaceContainer;
  Color get text => scheme.onSurface;
  Color get muted => scheme.onSurfaceVariant;
  Color get accent => scheme.secondary;
  Color get accentSurface => scheme.secondaryContainer;
  Color get border => scheme.outlineVariant;
  LinearGradient get highlightGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF155B42), Color(0xFF244D7A)]
        : const [Color(0xFFD6F3DF), Color(0xFFD5E8FC)],
  );
}

abstract final class AppTheme {
  static ThemeData build(Brightness brightness, {bool material3 = false}) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF60539C),
          brightness: brightness,
        ).copyWith(
          surface: dark ? const Color(0xFF17153B) : const Color(0xFFF7F5FC),
          surfaceContainer: dark ? const Color(0xFF272353) : Colors.white,
          onSurface: dark ? const Color(0xFFF4F3FA) : const Color(0xFF211E38),
          onSurfaceVariant: dark
              ? const Color(0xFFC5C0DC)
              : const Color(0xFF57516B),
          secondary: dark ? const Color(0xFF92E8F6) : const Color(0xFF00646D),
          secondaryContainer: dark
              ? const Color(0xFF263F48)
              : const Color(0xFFD4F0F1),
          onSecondaryContainer: dark
              ? const Color(0xFFC2F4F7)
              : const Color(0xFF003F46),
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radius),
    );
    return ThemeData(
      useMaterial3: material3,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardColor: scheme.surfaceContainer,
      dividerColor: scheme.outlineVariant,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: scheme.surfaceContainer),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: shape,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.page),
        helperMaxLines: 5,
        errorMaxLines: 5,
        alignLabelWithHint: true,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.secondary,
          minimumSize: const Size(48, 48),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }
}

/// Readers keep Material 3 controls while inheriting the selected appearance.
class AppReaderStyle extends StatelessWidget {
  const AppReaderStyle({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.build(Theme.of(context).brightness, material3: true),
    child: child,
  );
}
