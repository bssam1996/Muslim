import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

class RadioStation {
  final int id;
  final String englishName;
  final String arabicName;
  final String url;

  const RadioStation({
    required this.id,
    required this.englishName,
    required this.arabicName,
    required this.url,
  });

  String nameForLocale(BuildContext context) {
    if (context.locale.languageCode == 'ar' && arabicName.isNotEmpty) {
      return arabicName;
    }
    if (englishName.isNotEmpty) {
      return englishName;
    }
    return arabicName;
  }

  bool matches(String query) {
    final String normalizedQuery = normalizeRadioSearchText(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return normalizeRadioSearchText(englishName).contains(normalizedQuery) ||
        normalizeRadioSearchText(arabicName).contains(normalizedQuery);
  }
}

String normalizeRadioSearchText(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064b-\u065f\u0670]'), '')
      .replaceAll(RegExp('[\u0625\u0623\u0622\u0627]'), '\u0627')
      .replaceAll('\u0649', '\u064a')
      .replaceAll('\u0629', '\u0647')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
