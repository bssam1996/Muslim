import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'constants.dart';

class PrayerDateHeader extends StatelessWidget {
  const PrayerDateHeader({
    super.key,
    required this.gregorian,
    required this.hijri,
    required this.onMonthsHelp,
  });

  final DateTime gregorian;
  final Map<String, dynamic> hijri;
  final VoidCallback onMonthsHelp;

  String get _hijriLabel {
    final parts = (hijri['date']?.toString() ?? '').split('-');
    if (parts.length != 3) return hijri['date']?.toString() ?? '-';
    final monthNumber = int.tryParse(parts[1]);
    final month = hijriMonthsNames[monthNumber] ?? hijri['month']?['en'];
    if (month == null) return hijri['date'].toString();
    return '${int.tryParse(parts[0]) ?? parts[0]} ${month.toString().tr()} ${parts[2]}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Row(
        children: [
          Icon(Icons.calendar_month_outlined, color: palette.accent, size: 22),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMd(context.locale.toString()).format(gregorian),
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _hijriLabel,
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Months_Helper_Title'.tr(),
            onPressed: onMonthsHelp,
            icon: Icon(Icons.info_outline, color: palette.muted, size: 20),
          ),
        ],
      ),
    );
  }
}
