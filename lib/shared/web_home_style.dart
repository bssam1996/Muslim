import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const webCanvasColor = Color(0xFF141528);
const webPanelColor = Color(0xFF1D2038);
const webBorderColor = Color(0xFF30344D);
const webMutedColor = Color(0xFFA6AEC8);
const webAccentColor = Color(0xFF9CD9D3);
const webAccentSurface = Color(0xFF263F48);

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
            color: webPanelColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: webBorderColor),
          ),
          child: child,
        )
      : child;
}
