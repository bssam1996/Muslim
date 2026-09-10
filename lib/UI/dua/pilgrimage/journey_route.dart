import 'package:flutter/material.dart';
import 'pilgrimage_models.dart';
import 'pilgrimage_sources.dart';

/// The artwork is drawn locally. Labels and tap targets remain real widgets,
/// so resizing, Arabic, focus navigation and screen readers remain supported.
class JourneyStepMarker extends StatelessWidget {
  const JourneyStepMarker({
    super.key,
    required this.step,
    required this.number,
    required this.total,
    required this.selected,
    required this.visual,
    required this.onTap,
  });
  final PilgrimageStep step;
  final int number;
  final int total;
  final bool selected;
  final bool visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ar = pilgrimageArabic(context);
    final title = step.title.resolve(ar);
    final art = ExcludeSemantics(
      child: SizedBox(
        width: 58,
        height: 68,
        child: CustomPaint(painter: LandmarkPainter(step.landmark, colors)),
      ),
    );
    final label = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.stage.resolve(ar),
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (step.condition != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                pilgrimageLabel(
                  context,
                  'Includes guidance for your route',
                  'يتضمن إرشادات لمسارك',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                pilgrimageLabel(context, 'Selected step', 'الخطوة المحددة'),
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: true,
      onTap: onTap,
      selected: selected,
      label: ar
          ? 'الخطوة $number من $total: $title. فتح الدعاء والإرشادات.'
          : 'Step $number of $total: $title. Opens duaa and guidance.',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.only(
            top: visual ? 8 : 4,
            bottom: visual ? 22 : 4,
          ),
          child: CustomPaint(
            painter: visual && number < total
                ? _RouteLinkPainter(colors.outlineVariant, number.isEven)
                : null,
            child: Card(
              margin: EdgeInsetsDirectional.only(
                start: visual && number.isEven ? 20 : 0,
                end: visual && number.isOdd ? 20 : 0,
              ),
              clipBehavior: Clip.antiAlias,
              elevation: selected ? 3 : 0,
              color: selected
                  ? colors.primaryContainer
                  : colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: selected ? colors.primary : colors.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: InkWell(
                key: ValueKey('step-${step.id}'),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            child: Text(
                              '$number',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (visual) art,
                        ],
                      ),
                      const SizedBox(width: 14),
                      label,
                      const SizedBox(width: 6),
                      Icon(ar ? Icons.chevron_left : Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteLinkPainter extends CustomPainter {
  const _RouteLinkPainter(this.color, this.reverse);
  final Color color;
  final bool reverse;
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * (reverse ? .7 : .3);
    final end = size.width - x;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(x, size.height - 4)
      ..cubicTo(
        x,
        size.height + 16,
        end,
        size.height + 12,
        end,
        size.height + 30,
      );
    canvas.drawPath(path, paint);
    canvas.drawPath(
      Path()
        ..moveTo(end - 4, size.height + 23)
        ..lineTo(end, size.height + 29)
        ..lineTo(end + 4, size.height + 23),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RouteLinkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.reverse != reverse;
}

class LandmarkPainter extends CustomPainter {
  const LandmarkPainter(this.landmark, this.colors);
  final Landmark landmark;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 110);
    final ink = Paint()..color = colors.primary;
    final light = Paint()..color = colors.tertiary;
    canvas.drawOval(
      const Rect.fromLTWH(4, 83, 92, 13),
      Paint()..color = colors.primary.withValues(alpha: .12),
    );
    switch (landmark) {
      case Landmark.kaaba:
        canvas.drawPath(
          Path()
            ..moveTo(16, 33)
            ..lineTo(58, 22)
            ..lineTo(87, 37)
            ..lineTo(87, 79)
            ..lineTo(46, 93)
            ..lineTo(16, 74)
            ..close(),
          ink,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16, 44)
            ..lineTo(46, 60)
            ..lineTo(87, 46)
            ..lineTo(87, 54)
            ..lineTo(46, 68)
            ..lineTo(16, 52)
            ..close(),
          Paint()..color = const Color(0xFFE6BF77),
        );
        canvas.drawRect(
          const Rect.fromLTWH(57, 67, 13, 18),
          Paint()..color = const Color(0xFFE6BF77),
        );
      case Landmark.hills:
      case Landmark.mountain:
        canvas.drawPath(
          Path()
            ..moveTo(6, 86)
            ..lineTo(34, 32)
            ..lineTo(62, 86)
            ..close(),
          ink,
        );
        canvas.drawPath(
          Path()
            ..moveTo(35, 86)
            ..lineTo(69, 43)
            ..lineTo(95, 86)
            ..close(),
          light,
        );
        if (landmark == Landmark.mountain) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(31, 12, 6, 23),
              const Radius.circular(2),
            ),
            light,
          );
        }
      case Landmark.tents:
        for (final offset in [const Offset(7, 35), const Offset(50, 48)]) {
          canvas.drawPath(
            Path()
              ..moveTo(offset.dx, offset.dy + 33)
              ..lineTo(offset.dx + 20, offset.dy)
              ..lineTo(offset.dx + 41, offset.dy + 33)
              ..close(),
            ink,
          );
          canvas.drawRect(
            Rect.fromLTWH(offset.dx + 5, offset.dy + 33, 31, 15),
            light,
          );
        }
      case Landmark.night:
        canvas.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addOval(const Rect.fromLTWH(18, 12, 48, 48)),
            Path()..addOval(const Rect.fromLTWH(32, 5, 43, 43)),
          ),
          light,
        );
        canvas.drawPath(
          Path()
            ..moveTo(10, 86)
            ..quadraticBezierTo(38, 53, 56, 80)
            ..quadraticBezierTo(79, 65, 94, 87)
            ..close(),
          ink,
        );
        canvas.drawCircle(const Offset(78, 35), 3, ink);
      case Landmark.pillars:
        for (var i = 0; i < 3; i++) {
          canvas.drawOval(Rect.fromLTWH(3 + i * 31, 70, 31, 17), light);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(13 + i * 31, 27 + i * 7, 12, 51 - i * 7),
              const Radius.circular(5),
            ),
            ink,
          );
        }
      case Landmark.scissors:
        final stroke = Paint()
          ..color = colors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        canvas.drawCircle(const Offset(26, 76), 12, stroke);
        canvas.drawCircle(const Offset(74, 76), 12, stroke);
        canvas.drawLine(const Offset(34, 67), const Offset(72, 24), stroke);
        canvas.drawLine(const Offset(66, 67), const Offset(28, 24), stroke);
      case Landmark.sacrifice:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(14, 38, 62, 34),
            const Radius.circular(16),
          ),
          light,
        );
        canvas.drawOval(const Rect.fromLTWH(66, 27, 22, 31), ink);
        canvas.drawRect(const Rect.fromLTWH(25, 66, 7, 20), ink);
        canvas.drawRect(const Rect.fromLTWH(61, 66, 7, 20), ink);
      case Landmark.ihram:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(24, 24, 51, 62),
            const Radius.circular(10),
          ),
          ink,
        );
        canvas.drawPath(
          Path()
            ..moveTo(24, 30)
            ..lineTo(75, 46)
            ..lineTo(75, 59)
            ..lineTo(24, 43)
            ..close(),
          light,
        );
        canvas.drawLine(
          const Offset(25, 68),
          const Offset(73, 68),
          Paint()
            ..color = colors.onPrimary
            ..strokeWidth = 3,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LandmarkPainter oldDelegate) =>
      landmark != oldDelegate.landmark || colors != oldDelegate.colors;
}
