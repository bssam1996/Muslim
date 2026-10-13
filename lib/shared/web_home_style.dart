import 'package:muslim/shared/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool useWebHomeStyle(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= 600;

class WebPrayerPanel extends StatelessWidget {
  const WebPrayerPanel({super.key, required this.child, required this.styled});

  final Widget child;
  final bool styled;

  @override
  Widget build(BuildContext context) => styled
      ? Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppPalette.of(context).panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppPalette.of(context).border),
          ),
          child: child,
        )
      : child;
}
