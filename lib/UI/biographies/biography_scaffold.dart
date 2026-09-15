import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart';

const biographyHeadingStyle = TextStyle(
  color: textColor,
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
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: primaryColor,
      cardColor: thirdColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: highlightedColor,
        brightness: Brightness.dark,
        surface: thirdColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: textColor,
      ),
    ),
    child: Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    ),
  );
}
