import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/azkar/azkar_items.dart';
import 'package:muslim/UI/azkar/azkar_list.dart';
import 'package:muslim/shared/constants.dart';
import 'package:muslim/utils/api_utils.dart' as api_utils;
import 'package:shared_preferences/shared_preferences.dart';

class DailyRoutinePageClass extends StatefulWidget {
  const DailyRoutinePageClass({
    super.key,
    this.todayTimings = const <String, dynamic>{},
  });

  final Map<String, dynamic> todayTimings;

  @override
  State<DailyRoutinePageClass> createState() => _DailyRoutinePageClassState();
}

class _DailyRoutinePageClassState extends State<DailyRoutinePageClass> {
  static const String _storagePrefix = 'dailyRoutine';
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final DateFormat _keyFormatter = DateFormat('yyyy-MM-dd');

  bool _loading = true;
  bool _celebrationShown = false;
  String? _loadError;
  DateTime _routineDate = DateTime.now();
  DateTime? _routineStartsAt;
  DateTime? _routineEndsAt;
  List<_DailyRoutineItem> _items = <_DailyRoutineItem>[];
  Set<String> _checkedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  Future<void> _loadRoutine() async {
    try {
      final SharedPreferences prefs = await _prefs;
      await _cleanupOldDailyRoutineData(prefs);

      final DateTime now = DateTime.now();
      final DateTime today = _dateOnly(now);
      Map<String, dynamic> todayTimings = Map<String, dynamic>.from(
        widget.todayTimings,
      );
      todayTimings = await _ensureTimingsForOffset(todayTimings, 0);

      final DateTime? todayFajr = _timeOnDate(todayTimings, 'Fajr', today);
      final int routineOffset = todayFajr != null && now.isBefore(todayFajr)
          ? -1
          : 0;
      final DateTime routineDate = today.add(Duration(days: routineOffset));
      final Map<String, dynamic> routineTimings = routineOffset == 0
          ? todayTimings
          : await _ensureTimingsForOffset(<String, dynamic>{}, routineOffset);

      final DateTime? fajr = _timeOnDate(routineTimings, 'Fajr', routineDate);
      final DateTime? tomorrowFajr = todayFajr?.add(const Duration(days: 1));
      final DateTime? maghribToday = _timeOnDate(
        todayTimings,
        'Maghrib',
        today,
      );
      final _KahfWindow? kahfWindow = _activeKahfWindow(now, maghribToday);
      final List<_DailyRoutineItem> items = _buildItems(
        routineDate: routineDate,
        timings: routineTimings,
        kahfWindow: kahfWindow,
      );

      final Set<String> checkedKeys = <String>{};
      for (final _DailyRoutineItem item in items) {
        if (prefs.getBool(item.storageKey) ?? false) {
          checkedKeys.add(item.storageKey);
        }
      }

      if (!mounted) return;
      setState(() {
        _routineDate = routineDate;
        _routineStartsAt = fajr;
        _routineEndsAt = tomorrowFajr;
        _items = items;
        _checkedKeys = checkedKeys;
        _loading = false;
        _loadError = null;
      });
      _maybeCelebrate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<Map<String, dynamic>> _ensureTimingsForOffset(
    Map<String, dynamic> timings,
    int dayOffset,
  ) async {
    if (timings.containsKey('Fajr') && timings.containsKey('Maghrib')) {
      return timings;
    }

    final Map<String, dynamic> savedLocation = await api_utils
        .getSavedLocation();
    if (savedLocation['error'] != '') {
      return timings;
    }

    final Map<String, dynamic> data = await api_utils.getDataFromDay(
      dayOffset,
      savedLocation,
    );
    if (data['error'] != '') {
      return timings;
    }

    return Map<String, dynamic>.from(
      data['jsonData']['data']['timings'] as Map<dynamic, dynamic>,
    );
  }

  List<_DailyRoutineItem> _buildItems({
    required DateTime routineDate,
    required Map<String, dynamic> timings,
    required _KahfWindow? kahfWindow,
  }) {
    final DateTime? fajr = _timeOnDate(timings, 'Fajr', routineDate);
    final DateTime? sunrise = _timeOnDate(timings, 'Sunrise', routineDate);
    final DateTime? dhuhr = _timeOnDate(timings, 'Dhuhr', routineDate);
    final DateTime? asr = _timeOnDate(timings, 'Asr', routineDate);
    final DateTime? maghrib = _timeOnDate(timings, 'Maghrib', routineDate);
    final DateTime? isha = _timeOnDate(timings, 'Isha', routineDate);
    final String dayKey = _keyFormatter.format(routineDate);

    final List<_DailyRoutineItem> items = <_DailyRoutineItem>[
      _item(
        id: 'wakeup_dua',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Wakeup_Dua',
        subtitleKey: 'Daily_Routine_Subtitle_Wakeup_Dua',
        time: _orFallback(
          fajr?.subtract(const Duration(minutes: 45)),
          routineDate,
          4,
          45,
        ),
        icon: Icons.wb_twilight,
        accent: const Color(0xFF90CAF9),
        details: _detailsFromAzkar('Azkar_Wakeup'),
      ),
      _item(
        id: 'fajr_rawatib',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Fajr_Rawatib',
        subtitleKey: 'Daily_Routine_Subtitle_Fajr_Rawatib',
        time: _orFallback(
          fajr?.subtract(const Duration(minutes: 15)),
          routineDate,
          5,
          0,
        ),
        icon: Icons.mosque,
        accent: const Color(0xFF80DEEA),
        details: _rawatibDetails(
          'سنة الفجر',
          'ركعتان قبل صلاة الفجر، وهي من السنن الرواتب المؤكدة.',
        ),
      ),
      _afterPrayerItem(
        id: 'fajr_after_prayer',
        dayKey: dayKey,
        prayerName: 'Fajr',
        time: _orFallback(
          fajr?.add(const Duration(minutes: 10)),
          routineDate,
          5,
          20,
        ),
        extraText: 'تُقرأ المعوذات ثلاث مرات بعد الفجر.',
      ),
      _item(
        id: 'morning_azkar',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Morning_Azkar',
        subtitleKey: 'Daily_Routine_Subtitle_Morning_Azkar',
        time: _orFallback(
          fajr?.add(const Duration(minutes: 20)),
          routineDate,
          5,
          35,
        ),
        icon: Icons.wb_sunny,
        accent: const Color(0xFFFFD166),
        details: _detailsFromAzkar('Azkar_Morning'),
      ),
      _item(
        id: 'duha',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Duha',
        subtitleKey: 'Daily_Routine_Subtitle_Duha',
        time: _orFallback(
          sunrise?.add(const Duration(minutes: 20)),
          routineDate,
          8,
          0,
        ),
        icon: Icons.light_mode,
        accent: const Color(0xFFFFB74D),
        details: const <_RoutineDetail>[
          _RoutineDetail(
            title: 'صلاة الضحى',
            body:
                'وقتها من بعد شروق الشمس وارتفاعها بنحو ثلث ساعة إلى ما قبل الظهر، وأقلها ركعتان.',
          ),
        ],
      ),
      _item(
        id: 'dhuhr_before_rawatib',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Dhuhr_Before_Rawatib',
        subtitleKey: 'Daily_Routine_Subtitle_Dhuhr_Before_Rawatib',
        time: _orFallback(
          dhuhr?.subtract(const Duration(minutes: 15)),
          routineDate,
          11,
          45,
        ),
        icon: Icons.mosque,
        accent: const Color(0xFFA5D6A7),
        details: _rawatibDetails(
          'سنة الظهر القبلية',
          'أربع ركعات قبل صلاة الظهر، والأفضل أن تُصلى ركعتين ركعتين.',
        ),
      ),
      _afterPrayerItem(
        id: 'dhuhr_after_prayer',
        dayKey: dayKey,
        prayerName: 'Dhuhr',
        time: _orFallback(
          dhuhr?.add(const Duration(minutes: 10)),
          routineDate,
          12,
          15,
        ),
      ),
      _item(
        id: 'dhuhr_after_rawatib',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Dhuhr_After_Rawatib',
        subtitleKey: 'Daily_Routine_Subtitle_Dhuhr_After_Rawatib',
        time: _orFallback(
          dhuhr?.add(const Duration(minutes: 20)),
          routineDate,
          12,
          25,
        ),
        icon: Icons.mosque,
        accent: const Color(0xFFB2DFDB),
        details: _rawatibDetails(
          'سنة الظهر البعدية',
          'ركعتان بعد صلاة الظهر من السنن الرواتب.',
        ),
      ),
      _afterPrayerItem(
        id: 'asr_after_prayer',
        dayKey: dayKey,
        prayerName: 'Asr',
        time: _orFallback(
          asr?.add(const Duration(minutes: 10)),
          routineDate,
          15,
          45,
        ),
      ),
      _item(
        id: 'evening_azkar',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Evening_Azkar',
        subtitleKey: 'Daily_Routine_Subtitle_Evening_Azkar',
        time: _orFallback(
          asr?.add(const Duration(minutes: 20)),
          routineDate,
          16,
          0,
        ),
        icon: Icons.filter_drama,
        accent: const Color(0xFFFFA726),
        details: _detailsFromAzkar('Azkar_Night'),
      ),
      _afterPrayerItem(
        id: 'maghrib_after_prayer',
        dayKey: dayKey,
        prayerName: 'Maghrib',
        time: _orFallback(
          maghrib?.add(const Duration(minutes: 10)),
          routineDate,
          18,
          15,
        ),
        extraText: 'تُقرأ المعوذات ثلاث مرات بعد المغرب.',
      ),
      _item(
        id: 'maghrib_rawatib',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Maghrib_Rawatib',
        subtitleKey: 'Daily_Routine_Subtitle_Maghrib_Rawatib',
        time: _orFallback(
          maghrib?.add(const Duration(minutes: 20)),
          routineDate,
          18,
          25,
        ),
        icon: Icons.mosque,
        accent: const Color(0xFFFF8A65),
        details: _rawatibDetails(
          'سنة المغرب البعدية',
          'ركعتان بعد صلاة المغرب من السنن الرواتب.',
        ),
      ),
      if (kahfWindow != null)
        _item(
          id: 'surat_al_kahf',
          storageKey: '$_storagePrefix/kahf/${kahfWindow.storageDateKey}',
          titleKey: 'Daily_Routine_Item_Surat_Al_Kahf',
          subtitleKey: 'Daily_Routine_Subtitle_Surat_Al_Kahf',
          time: _orFallback(
            maghrib?.add(const Duration(minutes: 30)) ??
                kahfWindow.startsAt.add(const Duration(minutes: 30)),
            routineDate,
            18,
            35,
          ),
          icon: Icons.menu_book,
          accent: const Color(0xFFCE93D8),
          details: const <_RoutineDetail>[
            _RoutineDetail(
              title: 'سورة الكهف',
              body:
                  'تُقرأ سورة الكهف كاملة في ليلة الجمعة أو يومها. يبدأ وقتها من غروب شمس يوم الخميس إلى غروب شمس يوم الجمعة.',
            ),
          ],
        ),
      _afterPrayerItem(
        id: 'isha_after_prayer',
        dayKey: dayKey,
        prayerName: 'Isha',
        time: _orFallback(
          isha?.add(const Duration(minutes: 10)),
          routineDate,
          20,
          15,
        ),
      ),
      _item(
        id: 'isha_rawatib',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Isha_Rawatib',
        subtitleKey: 'Daily_Routine_Subtitle_Isha_Rawatib',
        time: _orFallback(
          isha?.add(const Duration(minutes: 20)),
          routineDate,
          20,
          25,
        ),
        icon: Icons.mosque,
        accent: const Color(0xFF9575CD),
        details: _rawatibDetails(
          'سنة العشاء البعدية',
          'ركعتان بعد صلاة العشاء من السنن الرواتب.',
        ),
      ),
      _item(
        id: 'witr',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Witr',
        subtitleKey: 'Daily_Routine_Subtitle_Witr',
        time: _orFallback(
          isha?.add(const Duration(minutes: 50)),
          routineDate,
          21,
          0,
        ),
        icon: Icons.nightlight_round,
        accent: const Color(0xFF7986CB),
        details: const <_RoutineDetail>[
          _RoutineDetail(
            title: 'صلاة الوتر',
            body:
                'ركعة واحدة أو أكثر بعد صلاة العشاء وقبل النوم لمن يخشى ألا يقوم آخر الليل.',
          ),
        ],
      ),
      _item(
        id: 'sleep_azkar',
        dayKey: dayKey,
        titleKey: 'Daily_Routine_Item_Sleep_Azkar',
        subtitleKey: 'Daily_Routine_Subtitle_Sleep_Azkar',
        time: _orFallback(
          isha?.add(const Duration(minutes: 65)),
          routineDate,
          21,
          15,
        ),
        icon: Icons.bedtime,
        accent: const Color(0xFF5C6BC0),
        details: <_RoutineDetail>[
          const _RoutineDetail(
            title: 'الوضوء قبل النوم',
            body:
                'من السنة أن يتوضأ المسلم قبل النوم، ثم ينام على جنبه الأيمن ويذكر الله.',
          ),
          ..._detailsFromAzkar('Azkar_Sleeping'),
        ],
      ),
    ];

    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }

  _DailyRoutineItem _afterPrayerItem({
    required String id,
    required String dayKey,
    required String prayerName,
    required DateTime time,
    String extraText = '',
  }) {
    final String titleKey = 'Daily_Routine_Item_${prayerName}_After_Prayer';
    return _item(
      id: id,
      dayKey: dayKey,
      titleKey: titleKey,
      subtitleKey: 'Daily_Routine_Subtitle_After_Prayer',
      time: time,
      icon: Icons.done_all,
      accent: const Color(0xFF4DD0E1),
      details: _afterPrayerDetails(extraText),
    );
  }

  _DailyRoutineItem _item({
    required String id,
    String? dayKey,
    String? storageKey,
    required String titleKey,
    required String subtitleKey,
    required DateTime time,
    required IconData icon,
    required Color accent,
    required List<_RoutineDetail> details,
  }) {
    return _DailyRoutineItem(
      id: id,
      storageKey: storageKey ?? '$_storagePrefix/$dayKey/$id',
      titleKey: titleKey,
      subtitleKey: subtitleKey,
      time: time,
      icon: icon,
      accent: accent,
      details: details,
    );
  }

  List<_RoutineDetail> _rawatibDetails(String title, String body) {
    return <_RoutineDetail>[
      _RoutineDetail(title: title, body: body),
      const _RoutineDetail(
        title: 'السنن الرواتب',
        body:
            'هي اثنتا عشرة ركعة في اليوم والليلة: ركعتان قبل الفجر، وأربع قبل الظهر وركعتان بعدها، وركعتان بعد المغرب، وركعتان بعد العشاء.',
      ),
    ];
  }

  List<_RoutineDetail> _detailsFromAzkar(String key) {
    final List<AzkarItem> items = AzkarCategories[key] ?? <AzkarItem>[];
    return items.map((AzkarItem item) {
      final StringBuffer body = StringBuffer(item.data);
      body.write('\n\nالتكرار: ${item.count}');
      if (item.description.trim().isNotEmpty) {
        body.write('\n${item.description}');
      }
      return _RoutineDetail(title: key.tr(), body: body.toString());
    }).toList();
  }

  List<_RoutineDetail> _afterPrayerDetails(String extraText) {
    final List<_RoutineDetail> details = <_RoutineDetail>[
      const _RoutineDetail(
        title: 'الاستغفار بعد الصلاة',
        body:
            'أَسْتَغْفِرُ اللهَ، أَسْتَغْفِرُ اللهَ، أَسْتَغْفِرُ اللهَ.\n\nاللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ.',
      ),
      const _RoutineDetail(
        title: 'الذكر بعد الصلاة',
        body:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ، وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.\n\nاللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ، وَلَا مُعْطِيَ لِمَا مَنَعْتَ، وَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ.',
      ),
      const _RoutineDetail(
        title: 'التسبيح والتحميد والتكبير',
        body:
            'سُبْحَانَ اللَّهِ ٣٣ مرة، وَالْحَمْدُ لِلَّهِ ٣٣ مرة، وَاللَّهُ أَكْبَرُ ٣٣ مرة.\n\nوتتم المائة بقول: لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
      ),
      const _RoutineDetail(
        title: 'آية الكرسي',
        body:
            'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ.',
      ),
      const _RoutineDetail(
        title: 'المعوذات',
        body:
            'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ.\n\nقُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ.\n\nقُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ.',
      ),
    ];
    if (extraText.isNotEmpty) {
      details.add(_RoutineDetail(title: 'تنبيه', body: extraText));
    }
    return details;
  }

  DateTime _orFallback(DateTime? value, DateTime date, int hour, int minute) {
    return value ?? DateTime(date.year, date.month, date.day, hour, minute);
  }

  DateTime? _timeOnDate(
    Map<String, dynamic> timings,
    String key,
    DateTime date,
  ) {
    final String? value = timings[key]?.toString();
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final String normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final RegExpMatch? match = RegExp(
      r'(\d{1,2})\s*:\s*(\d{2})',
    ).firstMatch(normalized);
    if (match == null) {
      return null;
    }

    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    if (normalized.contains('pm') && hour < 12) {
      hour += 12;
    }
    if (normalized.contains('am') && hour == 12) {
      hour = 0;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  _KahfWindow? _activeKahfWindow(DateTime now, DateTime? todayMaghrib) {
    final DateTime today = _dateOnly(now);
    if (now.weekday == DateTime.thursday) {
      if (todayMaghrib == null || !now.isBefore(todayMaghrib)) {
        return _KahfWindow(
          startsAt:
              todayMaghrib ?? DateTime(today.year, today.month, today.day, 18),
          storageDateKey: _keyFormatter.format(today),
        );
      }
    }
    if (now.weekday == DateTime.friday) {
      if (todayMaghrib == null || now.isBefore(todayMaghrib)) {
        final DateTime thursday = today.subtract(const Duration(days: 1));
        return _KahfWindow(
          startsAt: DateTime(thursday.year, thursday.month, thursday.day, 18),
          storageDateKey: _keyFormatter.format(thursday),
        );
      }
    }
    return null;
  }

  Future<void> _toggleItem(_DailyRoutineItem item) async {
    final SharedPreferences prefs = await _prefs;
    final bool checked = !_checkedKeys.contains(item.storageKey);
    await prefs.setBool(item.storageKey, checked);
    if (!mounted) return;
    setState(() {
      if (checked) {
        _checkedKeys.add(item.storageKey);
      } else {
        _checkedKeys.remove(item.storageKey);
        _celebrationShown = false;
      }
    });
    _maybeCelebrate();
  }

  Future<void> _cleanupOldDailyRoutineData(SharedPreferences prefs) async {
    final DateTime cutoff = _dateOnly(
      DateTime.now(),
    ).subtract(const Duration(days: 2));
    for (final String key in prefs.getKeys()) {
      if (!key.startsWith('$_storagePrefix/')) {
        continue;
      }
      final List<String> parts = key.split('/');
      if (parts.length < 3) {
        continue;
      }
      final String datePart = parts[1] == 'kahf' ? parts[2] : parts[1];
      try {
        final DateTime storedDate = DateTime.parse(datePart);
        if (storedDate.isBefore(cutoff)) {
          await prefs.remove(key);
        }
      } catch (_) {
        await prefs.remove(key);
      }
    }
  }

  void _maybeCelebrate() {
    if (_items.isEmpty ||
        _checkedKeys.length < _items.length ||
        _celebrationShown ||
        !mounted) {
      return;
    }
    _celebrationShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: highlightedBoxesBorderColor),
            ),
            title: Text(
              'Daily_Routine_Celebration_Title'.tr(),
              style: const TextStyle(color: textColor),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Daily_Routine_Celebration_Body'.tr(),
              style: const TextStyle(color: textColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK'.tr(),
                  style: const TextStyle(color: highlightedTextColor),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  void _showDetails(_DailyRoutineItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (BuildContext context) {
        final double maxHeight = MediaQuery.of(context).size.height * 0.82;
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.titleKey.tr(),
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: item.details.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: dividerColor, height: 24),
                        itemBuilder: (BuildContext context, int index) {
                          final _RoutineDetail detail = item.details[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                detail.title,
                                style: const TextStyle(
                                  color: highlightedTextColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                detail.body,
                                style: const TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  height: 1.8,
                                  fontFamily: 'Uthman',
                                ),
                                textAlign: TextAlign.right,
                                textDirection: ui.TextDirection.rtl,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: interpolatedColor3,
      appBar: AppBar(
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: textColor),
        title: Text(
          'Daily_Routine_Title'.tr(),
          style: const TextStyle(color: textColor),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: highlightedTextColor),
              )
            : _loadError != null
            ? _buildError()
            : Column(
                children: <Widget>[
                  _buildProgressHeader(),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            interpolatedColor3,
                            interpolatedColor6,
                            primaryColor,
                          ],
                        ),
                      ),
                      child: RefreshIndicator(
                        onRefresh: _loadRoutine,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                          itemCount: _items.length,
                          itemBuilder: (BuildContext context, int index) {
                            return _buildTimelineRow(_items[index], index);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              color: highlightedTextColor,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'Daily_Routine_Load_Error'.tr(),
              style: const TextStyle(color: textColor, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRoutine,
              icon: const Icon(Icons.refresh),
              label: Text('Reload'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    final int completed = _checkedKeys.length;
    final int total = _items.length;
    final double progress = total == 0 ? 0 : completed / total;
    final String dateText = DateFormat.yMMMd(
      context.locale.toLanguageTag(),
    ).format(_routineDate);
    final String startText = _routineStartsAt == null
        ? '-'
        : DateFormat.Hm().format(_routineStartsAt!);
    final String endText = _routineEndsAt == null
        ? '-'
        : DateFormat.Hm().format(_routineEndsAt!);

    return Container(
      width: double.infinity,
      color: primaryColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Image.asset(
                'assets/daily_routine/daily-routine.png',
                width: 38,
                height: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AutoSizeText(
                      'Daily_Routine_Progress_Title'.tr(
                        args: <String>[completed.toString(), total.toString()],
                      ),
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      minFontSize: 12,
                    ),
                    const SizedBox(height: 2),
                    AutoSizeText(
                      'Daily_Routine_Day_Window'.tr(
                        args: <String>[dateText, startText, endText],
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      minFontSize: 10,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: Colors.white24,
                      color: highlightedTextColor,
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                highlightedTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(_DailyRoutineItem item, int index) {
    final bool checked = _checkedKeys.contains(item.storageKey);
    final bool isFirst = index == 0;
    final bool isLast = index == _items.length - 1;
    final String time = DateFormat.Hm().format(item.time);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                time,
                textDirection: ui.TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : Colors.white30,
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: checked ? highlightedColor : item.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 1),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: item.accent.withValues(alpha: 0.28),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    checked ? Icons.check : item.icon,
                    color: primaryColor,
                    size: 18,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.white30,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Tooltip(
                message: 'Daily_Routine_Long_Press_Tip'.tr(),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: checked ? interpolatedColor5 : primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: checked
                          ? highlightedBoxesBorderColor
                          : item.accent,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _toggleItem(item),
                    onLongPress: () => _showDetails(item),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                AutoSizeText(
                                  item.titleKey.tr(),
                                  style: TextStyle(
                                    color: checked
                                        ? highlightedTextColor
                                        : textColor,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    decoration: checked
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                  maxLines: 2,
                                  minFontSize: 12,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                AutoSizeText(
                                  item.subtitleKey.tr(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  minFontSize: 10,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Transform.scale(
                            scale: math.min(
                              1.1,
                              MediaQuery.of(context).size.width / 360,
                            ),
                            child: Checkbox(
                              value: checked,
                              onChanged: (_) => _toggleItem(item),
                              activeColor: highlightedColor,
                              checkColor: primaryColor,
                              side: const BorderSide(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyRoutineItem {
  const _DailyRoutineItem({
    required this.id,
    required this.storageKey,
    required this.titleKey,
    required this.subtitleKey,
    required this.time,
    required this.icon,
    required this.accent,
    required this.details,
  });

  final String id;
  final String storageKey;
  final String titleKey;
  final String subtitleKey;
  final DateTime time;
  final IconData icon;
  final Color accent;
  final List<_RoutineDetail> details;
}

class _RoutineDetail {
  const _RoutineDetail({required this.title, required this.body});

  final String title;
  final String body;
}

class _KahfWindow {
  const _KahfWindow({required this.startsAt, required this.storageDateKey});

  final DateTime startsAt;
  final String storageDateKey;
}
