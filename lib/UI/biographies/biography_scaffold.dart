import 'package:flutter/material.dart';
import 'package:muslim/shared/app_theme.dart';

const biographyHeadingStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w600,
);

class BiographyScaffold extends StatelessWidget {
  const BiographyScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) => AppReaderStyle(
    child: Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    ),
  );
}
