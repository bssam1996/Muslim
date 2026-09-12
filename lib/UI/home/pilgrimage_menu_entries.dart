import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart';
import '../dua/pilgrimage/pilgrimage_journey_page.dart';

/// Home drawer destinations share the existing menu styling and open the
/// sourced journeys directly, without the old Umrah guide or a Duaa submenu.
class PilgrimageMenuEntries extends StatelessWidget {
  const PilgrimageMenuEntries({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final hajj in [false, true]) ...[
        ListTile(
          key: ValueKey(hajj ? 'home-hajj' : 'home-umrah'),
          title: Text(
            hajj ? 'Home_Panel_Hajj' : 'Home_Panel_Umrah',
            style: const TextStyle(color: textColor),
          ).tr(),
          trailing: Image.asset(
            hajj ? 'assets/hajj/hajj.png' : 'assets/umrah/main.png',
            width: 24,
            height: 24,
            excludeFromSemantics: true,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PilgrimageJourneyPage(hajj: hajj),
            ),
          ),
        ),
        const Divider(color: textColor),
      ],
    ],
  );
}
