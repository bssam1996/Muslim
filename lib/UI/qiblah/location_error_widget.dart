import 'package:muslim/shared/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';


class LocationErrorWidget extends StatelessWidget {
  const LocationErrorWidget({
    super.key,
    required this.error,
    this.callback,
    this.actionLabel,
    this.onRetry,
  });

  final String error;
  final VoidCallback? callback;
  final String? actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_off_outlined,
            size: 64,
            color: AppPalette.of(context).accent,
          ),
          const SizedBox(height: 20),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.of(context).text),
          ),
          if (callback != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: callback,
              child: Text(actionLabel ?? 'Reload'.tr()),
            ),
          ],
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text('Reload'.tr())),
        ],
      ),
    ),
  );
}
