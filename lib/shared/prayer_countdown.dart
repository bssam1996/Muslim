import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../utils/helper.dart' as helper;
import 'app_theme.dart';

class PrayerCountdown extends StatelessWidget {
  const PrayerCountdown({
    super.key,
    required this.name,
    required this.time,
    required this.clock,
    required this.displayTime,
  });
  final String name;
  final DateTime time;
  final String displayTime;
  final ValueNotifier<DateTime> clock;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime>(
    valueListenable: clock,
    builder: (context, now, _) {
      final palette = AppPalette.of(context);
      final remaining = time.difference(now);
      final duration = remaining.isNegative ? Duration.zero : remaining;
      return Container(
        key: const ValueKey('home_countdown'),
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: palette.highlightGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Column(
          children: [
            Text(
              '${(name == 'Sunrise' ? 'Home_Next_Event' : 'Home_Page_Next_Prayer').tr()} · ${name.tr()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${DateFormat.MMMd(context.locale.toString()).format(time)} · $displayTime',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Wrap(
                alignment: WrapAlignment.center,
                textDirection: TextDirection.ltr,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (part, label) in [
                    ('hour', 'Countdown_Hours'),
                    ('minute', 'Countdown_Minutes'),
                    ('second', 'Countdown_Seconds'),
                  ])
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          helper.constructTimeLeftSplitted(duration, part),
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          label.tr(),
                          style: TextStyle(color: palette.muted, fontSize: 11),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
