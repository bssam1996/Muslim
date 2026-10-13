import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../UI/azkar/azkar_page.dart';
import '../UI/biographies/biography_page.dart';
import '../UI/contact/contact.dart';
import '../UI/daily_routine/daily_routine_page.dart';
import '../UI/dua/dua_page.dart';
import '../UI/dua/pilgrimage/pilgrimage_journey_page.dart';
import '../UI/hadith/main_page.dart';
import '../UI/month/months_page.dart';
import '../UI/mosque/nearest_mosque_page.dart';
import '../UI/prayer_notifications/prayer_notifications.dart';
import '../UI/prophets/prophets_page.dart';
import '../UI/qiblah/qiblah_page.dart';
import '../UI/quran/quran_page.dart';
import '../UI/quiz/quiz_page.dart';
import '../UI/radio/radio_page.dart';
import '../UI/settings/settings.dart';
import '../utils/prayer_schedule.dart';
import 'app_theme.dart';

enum AppDestination {
  home,
  routine,
  azkar,
  dua,
  quran,
  hadith,
  prophets,
  biography,
  quiz,
  qiblah,
  mosques,
  calendar,
  radio,
  hajj,
  umrah,
  settings,
  notifications,
  contact;

  String get titleKey => switch (this) {
    home => 'Home_Panel_Prayer_Times',
    routine => 'Daily_Routine_Title',
    azkar => 'Home_Panel_Azkar',
    dua => 'Home_Panel_Dua',
    quran => 'Home_Panel_Quran',
    hadith => 'Home_Panel_Hadiths',
    prophets => 'Prophets_Title',
    biography => 'Biography_Title',
    quiz => 'Quiz_Title',
    qiblah => 'Home_Panel_Qiblah',
    mosques => 'Home_Utilities_Find_Nearest_Mosque',
    calendar => 'Home_Panel_Prayer_Calendar',
    radio => 'Home_Panel_Radio',
    hajj => 'Home_Panel_Hajj',
    umrah => 'Home_Panel_Umrah',
    settings => 'Home_Panel_Settings',
    notifications => 'Home_Panel_Prayer_Notifications',
    contact => 'Home_Panel_Contact',
  };

  IconData get icon => switch (this) {
    home => Icons.mosque_outlined,
    routine => Icons.task_alt,
    azkar => Icons.wb_sunny_outlined,
    dua => Icons.volunteer_activism_outlined,
    quran => Icons.menu_book_outlined,
    hadith => Icons.auto_stories_outlined,
    prophets => Icons.people_outline,
    biography => Icons.library_books_outlined,
    quiz => Icons.quiz_outlined,
    qiblah => Icons.explore_outlined,
    mosques => Icons.location_on_outlined,
    calendar => Icons.calendar_month_outlined,
    radio => Icons.radio_outlined,
    hajj || umrah => Icons.route_outlined,
    settings => Icons.settings_outlined,
    notifications => Icons.notifications_outlined,
    contact => Icons.contact_support_outlined,
  };

  Widget page({
    required Future<SharedPreferences> preferences,
    List<PrayerDay> prayerDays = const [],
  }) => switch (this) {
    home => throw StateError('Home is the root route'),
    routine => DailyRoutinePageClass(prayerDays: prayerDays),
    azkar => const AzkarPageClass(),
    dua => const DuaPageClass(),
    quran => const QuranPageClass(),
    hadith => const HadithHomePageClass(),
    prophets => const ProphetsPage(),
    biography => const BiographyPage(),
    quiz => const QuizPageClass(),
    qiblah => const QiblahClass(),
    mosques => const NearestMosquePageClass(),
    calendar => const MonthsPageClass(),
    radio => const RadioPageClass(),
    hajj => const PilgrimageJourneyPage(hajj: true),
    umrah => const PilgrimageJourneyPage(hajj: false),
    settings => SettingsPageClass(prefs: preferences),
    notifications => PrayerNotificationsPageClass(prefs: preferences),
    contact => const ContactPageClass(),
  };
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.onDestination,
    required this.onShare,
    required this.onRate,
    required this.footer,
    this.showQiblah = true,
    this.showNotifications = false,
  });
  final ValueChanged<AppDestination> onDestination;
  final VoidCallback onShare;
  final VoidCallback onRate;
  final Widget footer;
  final bool showQiblah;
  final bool showNotifications;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const PageStorageKey('app_drawer_scroll'),
                padding: const EdgeInsets.all(AppSpacing.small),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    child: Text(
                      'App_Title'.tr(),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  for (final (heading, destinations) in [
                    (
                      'Navigation_Daily',
                      [
                        AppDestination.routine,
                        AppDestination.azkar,
                        AppDestination.dua,
                      ],
                    ),
                    (
                      'Navigation_Read',
                      [
                        AppDestination.quran,
                        AppDestination.hadith,
                        AppDestination.prophets,
                        AppDestination.biography,
                        AppDestination.quiz,
                      ],
                    ),
                    (
                      'Navigation_Tools',
                      [
                        if (showQiblah) AppDestination.qiblah,
                        AppDestination.mosques,
                        AppDestination.calendar,
                        AppDestination.radio,
                        AppDestination.hajj,
                        AppDestination.umrah,
                      ],
                    ),
                    (
                      'Navigation_App',
                      [
                        AppDestination.settings,
                        if (showNotifications) AppDestination.notifications,
                        AppDestination.contact,
                      ],
                    ),
                  ]) ...[
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        16,
                        16,
                        8,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          heading.tr(),
                          style: TextStyle(
                            color: palette.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    for (final destination in destinations)
                      ListTile(
                        key: ValueKey('home-${destination.name}'),
                        leading: Icon(destination.icon, color: palette.accent),
                        title: Text(destination.titleKey.tr()),
                        onTap: () => onDestination(destination),
                      ),
                  ],
                  ListTile(
                    leading: const Icon(Icons.share_outlined),
                    title: Text('Home_Panel_Share'.tr()),
                    onTap: onShare,
                  ),
                  ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: Text('Home_Panel_Rate'.tr()),
                    onTap: onRate,
                  ),
                ],
              ),
            ),
            footer,
          ],
        ),
      ),
    );
  }
}
