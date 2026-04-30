import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/utils/homewidget_utils.dart';

void main() {
  const Map<String, String> timings24 = <String, String>{
    "fajr": "05:00",
    "sunrise": "06:20",
    "dhuhr": "12:10",
    "asr": "15:30",
    "maghrib": "18:00",
    "isha": "19:20",
  };

  const Map<String, String> timings12 = <String, String>{
    "fajr": "5:00 AM",
    "sunrise": "6:20 AM",
    "dhuhr": "12:10 PM",
    "asr": "3:30 PM",
    "maghrib": "6:00 PM",
    "isha": "7:20 PM",
  };

  test('before first prayer highlights fajr', () {
    final DateTime now = DateTime(2026, 4, 15, 4, 30);
    final NextPrayerState? state =
        computeNextPrayerStateFromTimings(timings24, now: now);
    expect(state, isNotNull);
    expect(state!.prayerKey, "fajr");
    expect(state.nextPrayerTime, DateTime(2026, 4, 15, 5, 0));
    expect(state.nextChangeTime, DateTime(2026, 4, 15, 6, 20));
  });

  test('between prayers highlights upcoming prayer', () {
    final DateTime now = DateTime(2026, 4, 15, 13, 0);
    final NextPrayerState? state =
        computeNextPrayerStateFromTimings(timings24, now: now);
    expect(state, isNotNull);
    expect(state!.prayerKey, "asr");
    expect(state.nextPrayerTime, DateTime(2026, 4, 15, 15, 30));
    expect(state.nextChangeTime, DateTime(2026, 4, 15, 18, 0));
  });

  test('after isha wraps to next day fajr', () {
    final DateTime now = DateTime(2026, 4, 15, 22, 0);
    final NextPrayerState? state =
        computeNextPrayerStateFromTimings(timings24, now: now);
    expect(state, isNotNull);
    expect(state!.prayerKey, "fajr");
    expect(state.nextPrayerTime, DateTime(2026, 4, 16, 5, 0));
    expect(state.nextChangeTime, DateTime(2026, 4, 16, 6, 20));
  });

  test('12-hour format timings are parsed correctly', () {
    final DateTime now = DateTime(2026, 4, 15, 13, 0);
    final NextPrayerState? state =
        computeNextPrayerStateFromTimings(timings12, now: now);
    expect(state, isNotNull);
    expect(state!.prayerKey, "asr");
    expect(state.nextPrayerTime, DateTime(2026, 4, 15, 15, 30));
    expect(state.nextChangeTime, DateTime(2026, 4, 15, 18, 0));
  });

  test('exact-minute boundary highlights that prayer', () {
    final DateTime now = DateTime(2026, 4, 15, 12, 10, 0);
    final NextPrayerState? state =
        computeNextPrayerStateFromTimings(timings24, now: now);
    expect(state, isNotNull);
    expect(state!.prayerKey, "dhuhr");
    expect(state.nextPrayerTime, DateTime(2026, 4, 15, 12, 10));
    expect(state.nextChangeTime, DateTime(2026, 4, 15, 15, 30));
  });
}
