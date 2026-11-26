import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:muslim/shared/app_theme.dart';

/// Bounds the web navigator and gives routes the size they actually occupy.
class ResponsiveWebViewport extends StatelessWidget {
  const ResponsiveWebViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, 1120.0);
      final mediaQuery = MediaQuery.of(context);
      return ColoredBox(
        color: AppPalette.of(context).canvas,
        child: Center(
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: MediaQuery(
              data: mediaQuery.copyWith(
                size: Size(width, mediaQuery.size.height),
              ),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

class HomeDashboardLayout extends StatelessWidget {
  const HomeDashboardLayout({
    super.key,
    required this.prayerPanel,
    required this.contentPanel,
    required this.allowWideLayout,
    this.stretchPanels = true,
  });

  final Widget prayerPanel;
  final Widget contentPanel;
  final bool allowWideLayout;
  final bool stretchPanels;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (allowWideLayout && constraints.maxWidth >= 960) {
        // Content-sized pagers need loose heights so their measurements can
        // update the table. Fixed widths avoid intrinsic viewport queries.
        return Table(
          columnWidths: const {
            0: FixedColumnWidth(420),
            1: FixedColumnWidth(24),
            2: FlexColumnWidth(),
          },
          defaultVerticalAlignment: stretchPanels
              ? TableCellVerticalAlignment.intrinsicHeight
              : TableCellVerticalAlignment.top,
          children: [
            TableRow(
              children: [prayerPanel, const SizedBox.shrink(), contentPanel],
            ),
          ],
        );
      }
      return Column(children: [prayerPanel, contentPanel]);
    },
  );
}
