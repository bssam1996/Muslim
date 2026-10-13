import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        alignment: Alignment.center,
        child: Semantics(
          liveRegion: true,
          label: 'Loading_Status'.tr(),
          child: const CircularProgressIndicator(),
        ),
      );
    }
    final widget = (Platform.isAndroid)
        ? const CircularProgressIndicator()
        : const CupertinoActivityIndicator();
    return Container(
      alignment: Alignment.center,
      child: Semantics(
        liveRegion: true,
        label: 'Loading_Status'.tr(),
        child: widget,
      ),
    );
  }
}
