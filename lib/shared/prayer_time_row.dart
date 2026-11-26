import 'package:flutter/material.dart';
import 'app_theme.dart';

class PrayerTimeRow extends StatelessWidget {
  const PrayerTimeRow({
    super.key,
    required this.label,
    required this.time,
    this.selected = false,
    this.dense = false,
  });
  final String label;
  final String time;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = TextStyle(
      color: selected ? palette.accent : palette.text,
      fontSize: 16,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );
    final title = Text(label, style: style);
    final clock = Text(time, textDirection: TextDirection.ltr, style: style);
    return Semantics(
      selected: selected,
      child: Container(
        constraints: BoxConstraints(minHeight: dense ? 44 : 52),
        margin: EdgeInsets.symmetric(vertical: dense ? 3 : 4),
        padding: EdgeInsets.all(dense ? AppSpacing.small : AppSpacing.medium),
        decoration: BoxDecoration(
          color: selected ? null : palette.panel,
          gradient: selected ? palette.highlightGradient : null,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: selected ? palette.accent : palette.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 280 &&
                MediaQuery.textScalerOf(context).scale(16) > 24) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  title,
                  const SizedBox(height: AppSpacing.small),
                  clock,
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: title,
                  ),
                ),
                const SizedBox(width: 64),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: clock,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
