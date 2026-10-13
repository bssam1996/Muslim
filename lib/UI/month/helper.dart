import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart';

Dialog showdialog(
  BuildContext context, {
  String? calendarMethod,
  int? adjustment,
}) => Dialog(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Months_Helper_Title'.tr(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (calendarMethod != null)
          Text(
            'Calendar_Method_Summary'.tr(
              namedArgs: {'method': calendarMethod.tr()},
            ),
          ),
        if (adjustment != null)
          Text(
            'Calendar_Adjustment_Summary'.tr(
              namedArgs: {'days': adjustment.toString()},
            ),
          ),
        for (final entry in hijriMonthsNames.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('${entry.key}. ${entry.value.tr()}'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'.tr()),
        ),
      ],
    ),
  ),
);

String? convertGregorianMonthToString(int month) {
  Map<int, String> months = {
    1: "January",
    2: "February",
    3: "March",
    4: "April",
    5: "May",
    6: "June",
    7: "July",
    8: "August",
    9: "September",
    10: "October",
    11: "November",
    12: "December",
  };
  return months[month];
}
