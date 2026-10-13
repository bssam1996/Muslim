import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'app_status.dart';

class RetryNotice extends StatelessWidget {
  const RetryNotice({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AppStatus(
    message: message,
    actionLabel: 'Reload'.tr(),
    onAction: onRetry,
  );
}
