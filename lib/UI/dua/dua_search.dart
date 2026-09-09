class DuaSearch {
  const DuaSearch._();

  // The current easy_localization version exposes only the active locale. Keep
  // a compact bilingual index so either language can be searched at any time.
  static const Map<String, List<String>> _titleTerms = <String, List<String>>{
    'Dua_Umrah': <String>['Umrah', 'العمرة'],
    'Dua_Hajj': <String>['Hajj', 'الحج'],
    'Dua_Umrah_Talbiyah': <String>['Talbiyah', 'التلبية'],
    'Dua_Umrah_Tawaf': <String>[
      'Dua between the Yemeni Corner and the Black Stone',
      'الدعاء بين الركن اليماني والحجر الأسود',
    ],
    'Dua_Umrah_Sai': <String>[
      'Dua at Safa and Marwah',
      'الدعاء على الصفا والمروة',
    ],
    'Dua_Travel': <String>['Travel', 'السفر'],
    'Dua_Makkah_To_Mina': <String>['Makkah To Mina', 'مكه للمنى'],
    'Dua_Arafat_Way': <String>['Way To Arafat', 'الطريق الى عرفات'],
    'Dua_Arafat': <String>['Arafat', 'عرفات'],
    'Dua_Arafat_Night': <String>['Arafat Night', 'مساء يوم عرفات'],
    'Dua_Arafat_To_Muzdalifah': <String>[
      'Arafat to Muzdalifah',
      'عرفات للمزدلفة',
    ],
    'Dua_Jamarat_Throwing': <String>['Jamarat Throwing', 'رمي الجمرات'],
    'Dua_Mina_Nahr': <String>['Yawm al-Nahr', 'يوم النحر'],
    'Dua_Mina_Tashreeq': <String>['Tashreeq Days', 'ايام التشريق'],
  };

  static Iterable<String> titleTerms(String titleKey) {
    if (titleKey == 'Dua_Hajj_Finishing') {
      return const <String>['Hajj Finishing', 'الانتهاء من الحج'];
    }
    return _titleTerms[titleKey] ?? <String>[titleKey];
  }

  /// Matches every word in [query] against one of the supplied texts.
  ///
  /// Arabic diacritics and commonly interchangeable letter forms are ignored,
  /// so, for example, both "مكة" and "مكّة" find the same dua.
  static bool matches(String query, Iterable<String> searchableTexts) {
    final List<String> queryTerms = _normalise(
      query,
    ).split(RegExp(r'\s+')).where((String term) => term.isNotEmpty).toList();

    if (queryTerms.isEmpty) {
      return true;
    }

    return searchableTexts.any((String text) {
      final String normalisedText = _normalise(text);
      return queryTerms.every(normalisedText.contains);
    });
  }

  static String _normalise(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll(RegExp(r'[إأآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }
}
