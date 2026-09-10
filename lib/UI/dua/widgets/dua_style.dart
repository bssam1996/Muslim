import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart' as app;
import '../models/dua_catalog.dart';

bool duaArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';
String dl(BuildContext context, String en, String ar) =>
    duaArabic(context) ? ar : en;
String dt(BuildContext context, DuaText text) =>
    text.resolve(duaArabic(context));

const duaCategoryIcons = <String, IconData>{
  'daily': Icons.checkroom_outlined,
  'food': Icons.restaurant_outlined,
  'travel': Icons.route_outlined,
  'worry': Icons.favorite_border,
  'learning': Icons.auto_stories_outlined,
  'family': Icons.family_restroom,
  'health': Icons.healing_outlined,
  'loss': Icons.spa_outlined,
  'gratitude': Icons.card_giftcard,
  'faith': Icons.volunteer_activism_outlined,
  'weather': Icons.cloud_outlined,
  'worship': Icons.mosque_outlined,
  'provision': Icons.work_outline,
};

class DuaStyle extends StatelessWidget {
  const DuaStyle({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: app.thirdColor,
      secondary: app.highlightedColor,
      brightness: MediaQuery.platformBrightnessOf(context),
    );
    return MediaQuery(
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
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

String duaOriginLabel(
  BuildContext context,
  DuaEntry entry,
  DuaCatalog catalog,
) {
  if (entry.origin == 'quran') return dl(context, 'Qur’an', 'القرآن');
  return entry.sourceIds.any((id) => catalog.sources[id]!.grade == 'hasan')
      ? dl(context, 'Hasan report', 'حديث حسن')
      : dl(context, 'Sahih report', 'حديث صحيح');
}

class DuaNotice extends StatelessWidget {
  const DuaNotice({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(text),
  );
}
