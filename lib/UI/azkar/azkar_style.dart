import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart' as app;

String azkarLabel(BuildContext context, String en, String ar) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

/// Native vector icons stay crisp at every text scale and need no downloads.
const azkarIcons = <String, IconData>{
  'Azkar_Morning': Icons.wb_sunny_outlined,
  'Azkar_Night': Icons.nights_stay_outlined,
  'Azkar_After_Praying': Icons.mosque_outlined,
  'Azkar_Sleeping': Icons.bedtime_outlined,
  'Azkar_Wakeup': Icons.wb_twilight,
  'Tasabeeh': Icons.grain,
};

const azkarNames = <String, (String, String)>{
  'Azkar_Morning': ('Morning', 'الصباح'),
  'Azkar_Night': ('Evening', 'المساء'),
  'Azkar_After_Praying': ('After prayer', 'بعد الصلاة'),
  'Azkar_Sleeping': ('Before sleep', 'قبل النوم'),
  'Azkar_Wakeup': ('Waking up', 'الاستيقاظ'),
  'Tasabeeh': ('Tasabeeh', 'تسابيح'),
};

String azkarName(BuildContext context, String key) {
  final name = azkarNames[key];
  return name == null ? key : azkarLabel(context, name.$1, name.$2);
}

class AzkarStyle extends StatelessWidget {
  const AzkarStyle({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: app.thirdColor,
      secondary: app.highlightedColor,
      brightness: MediaQuery.platformBrightnessOf(context),
    );
    return MediaQuery(
      // The app root fixes text scale at 1. Respect accessibility in this flow.
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQueryData.fromView(View.of(context)).textScaler,
      ),
      child: Theme(
        data: ThemeData(
          useMaterial3: true,
          colorScheme: colors,
          scaffoldBackgroundColor: colors.surface,
          appBarTheme: AppBarTheme(
            backgroundColor: colors.surface,
            foregroundColor: colors.onSurface,
            centerTitle: false,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

class AzkarIcon extends StatelessWidget {
  const AzkarIcon({super.key, required this.icon, this.size = 56});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Icon(
      icon,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
      size: size * .48,
    ),
  );
}
