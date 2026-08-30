import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:seeip_client/seeip_client.dart';

class PrayerLocation {
  const PrayerLocation({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    required this.cityCountry,
    required this.source,
  });

  final double latitude;
  final double longitude;

  /// Full name used when presenting a search result to the user.
  final String displayName;

  /// The concise label used throughout the app, for example London, United Kingdom.
  final String cityCountry;
  final String source;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'coordinates',
    'latitude': latitude,
    'longitude': longitude,
    'displayName': displayName,
    'cityCountry': cityCountry,
    'source': source,
  };
}

class PrayerLocationException implements Exception {
  const PrayerLocationException(this.translationKey);

  final String translationKey;
}

/// Obtains a precise device position and resolves a concise City, Country label.
Future<PrayerLocation> getCurrentPrayerLocation({http.Client? client}) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const PrayerLocationException('Settings_Location_Service_Disabled');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const PrayerLocationException('Settings_Location_Permission_Denied');
  }
  if (permission == LocationPermission.deniedForever) {
    throw const PrayerLocationException(
      'Settings_Location_Permission_Denied_Forever',
    );
  }

  try {
    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return resolvePrayerLocationCoordinates(
      position.latitude,
      position.longitude,
      source: 'gps',
      client: client,
    );
  } on PrayerLocationException {
    rethrow;
  } catch (_) {
    throw const PrayerLocationException('Settings_Location_Unavailable');
  }
}

Future<PrayerLocation> resolvePrayerLocationCoordinates(
  double latitude,
  double longitude, {
  required String source,
  http.Client? client,
}) async {
  final _ResolvedAddress resolvedAddress = await _reverseGeocode(
    latitude,
    longitude,
    client: client,
  );
  return PrayerLocation(
    latitude: latitude,
    longitude: longitude,
    displayName: resolvedAddress.displayName,
    cityCountry: resolvedAddress.cityCountry,
    source: source,
  );
}

Future<List<PrayerLocation>> searchPrayerLocations(
  String query, {
  http.Client? client,
}) async {
  final String trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) return <PrayerLocation>[];

  final Uri uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'format': 'jsonv2',
    'addressdetails': '1',
    'limit': '5',
    'q': trimmedQuery,
  });
  try {
    final http.Response response =
        await (client?.get(uri, headers: _nominatimHeaders) ??
                http.get(uri, headers: _nominatimHeaders))
            .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw const PrayerLocationException('Settings_Location_Search_Error');
    }
    final dynamic payload = jsonDecode(response.body);
    if (payload is! List) {
      throw const PrayerLocationException('Settings_Location_Search_Error');
    }
    return payload
        .whereType<Map>()
        .map((dynamic item) => _locationFromNominatim(item))
        .whereType<PrayerLocation>()
        .toList();
  } on PrayerLocationException {
    rethrow;
  } catch (_) {
    throw const PrayerLocationException('Settings_Location_Search_Error');
  }
}

Future<String> getIpLocationEstimate() async {
  try {
    final SeeipClient client = SeeipClient();
    final dynamic ip = await client.getIP();
    final dynamic location = await client.getGeoIP(ip.ip);
    final List<String> parts = <String>[
      location.city?.toString().trim() ?? '',
      location.country?.toString().trim() ?? '',
    ].where((String part) => part.isNotEmpty).toList();
    if (parts.length < 2) {
      throw const PrayerLocationException(
        'Settings_Location_Ip_Estimate_Unavailable',
      );
    }
    return parts.join(', ');
  } on PrayerLocationException {
    rethrow;
  } catch (_) {
    throw const PrayerLocationException(
      'Settings_Location_Ip_Estimate_Unavailable',
    );
  }
}

Future<_ResolvedAddress> _reverseGeocode(
  double latitude,
  double longitude, {
  http.Client? client,
}) async {
  final Uri uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
    'format': 'jsonv2',
    'lat': latitude.toString(),
    'lon': longitude.toString(),
  });
  try {
    final http.Response response =
        await (client?.get(uri, headers: _nominatimHeaders) ??
                http.get(uri, headers: _nominatimHeaders))
            .timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) {
      final dynamic payload = jsonDecode(response.body);
      if (payload is Map && payload['display_name'] is String) {
        final String? cityCountry = _cityCountryFromNominatim(payload);
        if (cityCountry != null) {
          return _ResolvedAddress(
            displayName: payload['display_name'] as String,
            cityCountry: cityCountry,
          );
        }
      }
    }
  } catch (_) {
    // The home screen must display City, Country, so an incomplete lookup is
    // intentionally not saved as a prayer-time location.
  }
  throw const PrayerLocationException(
    'Settings_Location_City_Country_Unavailable',
  );
}

PrayerLocation? _locationFromNominatim(Map<dynamic, dynamic> item) {
  final double? latitude = double.tryParse(item['lat']?.toString() ?? '');
  final double? longitude = double.tryParse(item['lon']?.toString() ?? '');
  final String? displayName = item['display_name']?.toString();
  if (latitude == null || longitude == null || displayName == null) {
    return null;
  }
  return PrayerLocation(
    latitude: latitude,
    longitude: longitude,
    displayName: displayName,
    // The selected location is reverse-geocoded before it is saved. This is
    // only a temporary value for rendering search results.
    cityCountry: _cityCountryFromNominatim(item) ?? '',
    source: 'search',
  );
}

String? _cityCountryFromNominatim(Map<dynamic, dynamic> payload) {
  final dynamic rawAddress = payload['address'];
  if (rawAddress is! Map) return null;
  final String? city = _firstNonEmptyValue(rawAddress, <String>[
    'city',
    'town',
    'village',
    'municipality',
    'county',
  ]);
  final String? country = _firstNonEmptyValue(rawAddress, <String>['country']);
  if (city == null || country == null) return null;
  return '$city, $country';
}

String? _firstNonEmptyValue(Map<dynamic, dynamic> values, List<String> keys) {
  for (final String key in keys) {
    final String value = values[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
}

class _ResolvedAddress {
  const _ResolvedAddress({
    required this.displayName,
    required this.cityCountry,
  });

  final String displayName;
  final String cityCountry;
}

const Map<String, String> _nominatimHeaders = <String, String>{
  'User-Agent': 'MuslimGuide/2.11 (prayer-time location search)',
};
