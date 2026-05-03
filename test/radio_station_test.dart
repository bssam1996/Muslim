import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/radio/radio_station.dart';
import 'package:muslim/UI/radio/radio_stations_data.dart';

void main() {
  test('radio stations are embedded as validated constants', () {
    expect(radioStations, hasLength(156));
    expect(
      radioStations.map((station) => station.id),
      orderedEquals(
        List<int>.generate(radioStations.length, (index) => index + 1),
      ),
    );
    expect(radioStations.every((station) => station.url.isNotEmpty), isTrue);
    expect(
      radioStations.every((station) => station.englishName.isNotEmpty),
      isTrue,
    );
    expect(
      radioStations.any(
        (station) => RegExp(r'[\u0600-\u06FF]').hasMatch(station.englishName),
      ),
      isFalse,
    );
    expect(
      radioStations.every(
        (station) =>
            station.url.startsWith('https://') ||
            station.url.startsWith('http://'),
      ),
      isTrue,
    );
    expect(
      radioStations
          .firstWhere(
            (station) => station.englishName == 'Holy Quran from Saudia Arabia',
          )
          .url,
      'https://stream.radiojar.com/0tpy1h0kxtzuv',
    );
    expect(
      radioStations
          .firstWhere(
            (station) => station.url
                .startsWith('https://n0e.radiojar.com/8s5u5tpdtwzuv'),
          )
          .englishName,
      'Holy Quran Radio from Cairo',
    );
    expect(
      radioStations
          .firstWhere(
            (station) => station.url
                .startsWith('https://n01.radiojar.com/x0vs2vzy6k0uv'),
          )
          .englishName,
      'Prophetic Sunnah Radio',
    );
  });

  test('search matches English and Arabic names without choosing a language',
      () {
    const RadioStation station = RadioStation(
      id: 1,
      englishName: 'Radio Ibrahim Al-Akdar',
      arabicName:
          '\u0625\u0630\u0627\u0639\u0629 \u0625\u0628\u0631\u0627\u0647\u064a\u0645 \u0627\u0644\u0623\u062e\u0636\u0631',
      url: 'https://backup.qurango.net/radio/ibrahim_alakdar',
    );

    expect(station.matches('ibrahim'), isTrue);
    expect(
        station.matches('\u0627\u0628\u0631\u0627\u0647\u064a\u0645'), isTrue);
    expect(
      station.matches(
        '\u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f',
      ),
      isFalse,
    );
  });
}
