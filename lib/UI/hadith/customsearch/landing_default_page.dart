import 'package:muslim/shared/app_status.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class CustomSearchLandingPageClass extends StatelessWidget {
  const CustomSearchLandingPageClass({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: AppStatus(message: text.tr(), icon: Icons.search_outlined),
  );
}
