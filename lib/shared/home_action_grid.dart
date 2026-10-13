import 'package:muslim/shared/app_theme.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class HomeActionGrid extends StatelessWidget {
  const HomeActionGrid({
    super.key,
    required this.children,
    required this.compact,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final bool compact;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (MediaQuery.textScalerOf(context).scale(14) > 18) {
        final columns = constraints.maxWidth < 600 ? 1 : 2;
        final width =
            (constraints.maxWidth - AppSpacing.medium * (columns - 1)) /
            columns;
        return Wrap(
          spacing: AppSpacing.medium,
          runSpacing: AppSpacing.medium,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      }
      final columns = compact
          ? ((constraints.maxWidth + 12) / 192).floor().clamp(2, maxColumns)
          : 2;
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns.clamp(1, children.length.clamp(1, 4)),
          crossAxisSpacing: compact ? 12 : 8,
          mainAxisSpacing: compact ? 12 : 8,
          mainAxisExtent: compact ? 112 : null,
          childAspectRatio: 1.45,
        ),
        children: children,
      );
    },
  );
}

class HomeActionTile extends StatelessWidget {
  const HomeActionTile({
    super.key,
    required this.title,
    required this.assetPath,
    required this.onTap,
    this.icon,
    this.styled = false,
  });

  final String title;
  final String assetPath;
  final VoidCallback onTap;
  final IconData? icon;
  final bool styled;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: title,
    child: Card(
      margin: EdgeInsets.zero,
      color: styled
          ? AppPalette.of(context).panel
          : AppPalette.of(context).canvas,
      elevation: styled ? 0 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(styled ? 18 : 8),
        side: BorderSide(
          color: styled
              ? AppPalette.of(context).border
              : AppPalette.of(context).border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(styled ? 18 : 8),
        hoverColor: styled
            ? AppPalette.of(context).accent.withValues(alpha: .08)
            : null,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (MediaQuery.textScalerOf(context).scale(14) > 18) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: icon == null
                          ? Image.asset(assetPath, width: 36, height: 36)
                          : Icon(icon, color: AppPalette.of(context).accent),
                    ),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppPalette.of(context).text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            if (styled) {
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppPalette.of(
                          context,
                        ).accent.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: icon != null
                          ? Icon(
                              icon,
                              size: 23,
                              color: AppPalette.of(context).accent,
                            )
                          : Padding(
                              padding: const EdgeInsets.all(10),
                              child: Image.asset(assetPath),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.of(context).text,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppPalette.of(context).muted,
                    ),
                  ],
                ),
              );
            }
            final titleFontSize = (constraints.biggest.shortestSide * 0.14)
                .clamp(12.0, 16.0);
            return Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    assetPath,
                    width: 36,
                    height: 36,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: AutoSizeText(
                      title,
                      style: TextStyle(
                        color: AppPalette.of(context).text,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      minFontSize: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
