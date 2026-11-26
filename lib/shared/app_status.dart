import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppStatus extends StatelessWidget {
  const AppStatus({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.small),
        padding: const EdgeInsets.all(AppSpacing.page),
        decoration: BoxDecoration(
          color: palette.panel,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, color: palette.accent),
                const SizedBox(width: AppSpacing.medium),
                Expanded(child: Text(message)),
              ],
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.small),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
