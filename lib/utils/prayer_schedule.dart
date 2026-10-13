/// Calendar dates and prayer occurrences for the explicitly saved location.
/// Clock values retain the app's existing device-local interpretation.
const prayerEvents = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
const prayerWindowDays = 7;

DateTime prayerDate(DateTime value, [int offset = 0]) =>
    DateTime(value.year, value.month, value.day + offset);

String prayerDateKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String prayerConfigurationIdentity(String apiPath) =>
    apiPath.substring(apiPath.indexOf('?') + 1);

DateTime? prayerTimeOnDate(Object? raw, DateTime date) {
  if (raw is! String) return null;
  var value = raw.trim().toLowerCase();
  for (var i = 0; i < 10; i++) {
    value = value
        .replaceAll(String.fromCharCode(0x660 + i), '$i')
        .replaceAll(String.fromCharCode(0x6f0 + i), '$i');
  }
  final match = RegExp(r'^(\d{1,2})\s*:\s*(\d{2})(?:\s|$)').firstMatch(value);
  if (match == null) return null;
  var hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  final am = RegExp(r'(^|\s)(am|ص)(\s|$)').hasMatch(value);
  final pm = RegExp(r'(^|\s)(pm|م)(\s|$)').hasMatch(value);
  if (minute > 59 || (am && pm)) return null;
  if (am || pm) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (pm ? 12 : 0);
  } else if (hour > 23) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}

class PrayerDay {
  PrayerDay(
    DateTime date,
    Map<String, dynamic> timings, {
    Map<String, dynamic> dateData = const {},
  }) : date = prayerDate(date),
       dateData = Map.unmodifiable(dateData),
       times = Map.unmodifiable({
         for (final name in prayerEvents)
           name:
               prayerTimeOnDate(timings[name], date) ??
               (throw FormatException('Invalid $name time')),
       });

  factory PrayerDay.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date'] as String);
    if (prayerDateKey(date) != json['date']) {
      throw const FormatException('Invalid prayer snapshot date');
    }
    return PrayerDay(
      date,
      Map<String, dynamic>.from(json['timings'] as Map),
      dateData: Map<String, dynamic>.from(json['dateData'] as Map? ?? {}),
    );
  }

  final DateTime date;
  final Map<String, DateTime> times;
  final Map<String, dynamic> dateData;
  Map<String, dynamic> get timings => {
    for (final entry in times.entries)
      entry.key:
          '${entry.value.hour.toString().padLeft(2, '0')}:${entry.value.minute.toString().padLeft(2, '0')}',
  };
  Map<String, dynamic> toJson() => {
    'date': prayerDateKey(date),
    'timings': timings,
    'dateData': dateData,
  };
}

class PrayerOccurrence {
  const PrayerOccurrence(this.name, this.time);
  final String name;
  final DateTime time;
}

PrayerOccurrence? nextPrayerOccurrence(Iterable<PrayerDay> days, DateTime now) {
  final byDate = {for (final day in days) day.date: day};
  final contiguousDays = <PrayerDay>[];
  var date = prayerDate(now);
  while (byDate.containsKey(date)) {
    contiguousDays.add(byDate[date]!);
    date = prayerDate(date, 1);
  }
  final occurrences = [
    for (final day in contiguousDays)
      for (final entry in day.times.entries)
        if (!entry.value.isBefore(now))
          PrayerOccurrence(entry.key, entry.value),
  ]..sort((a, b) => a.time.compareTo(b.time));
  return occurrences.isEmpty ? null : occurrences.first;
}

class RoutinePrayerWindow {
  const RoutinePrayerWindow(this.date, this.startsAt, this.endsAt);
  final DateTime date;
  final DateTime? startsAt;
  final DateTime? endsAt;
}

RoutinePrayerWindow routinePrayerWindow({
  required DateTime now,
  PrayerDay? yesterday,
  PrayerDay? today,
  PrayerDay? tomorrow,
}) {
  final date = prayerDate(now);
  final todayFajr = today?.date == date ? today?.times['Fajr'] : null;
  if (todayFajr != null && now.isBefore(todayFajr)) {
    final previous = prayerDate(now, -1);
    return RoutinePrayerWindow(
      previous,
      yesterday?.date == previous ? yesterday?.times['Fajr'] : null,
      todayFajr,
    );
  }
  final nextDate = prayerDate(now, 1);
  return RoutinePrayerWindow(
    date,
    todayFajr,
    tomorrow?.date == nextDate ? tomorrow?.times['Fajr'] : null,
  );
}
