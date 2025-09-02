import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../shared/constants.dart';

class CustomSearchLandingPageClass extends StatelessWidget {

  const CustomSearchLandingPageClass({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Text(text, style: const TextStyle(fontSize: 24, color: textColor),).tr()
      ),
    );
  }
}
