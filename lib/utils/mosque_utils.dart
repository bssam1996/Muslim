import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MosqueSearchLocation {
  final double latitude;
  final double longitude;
  final bool fromFallback;

  const MosqueSearchLocation({
    required this.latitude,
    required this.longitude,
    required this.fromFallback,
  });
}

class MosqueLocationException implements Exception {
  final String translationKey;

  const MosqueLocationException(this.translationKey);

  @override
  String toString() => translationKey;
}

class MosqueSearchResult {
  final List<MosquePlace> mosques;
  final int radiusMeters;

  const MosqueSearchResult({required this.mosques, required this.radiusMeters});
}

class MosquePlace {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String address;

  const MosquePlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.address,
  });
}

const String _lastKnownLatitudeKey = 'nearestMosqueLastLatitude';
const String _lastKnownLongitudeKey = 'nearestMosqueLastLongitude';

Future<MosqueSearchLocation> getMosqueSearchLocation() async {
  final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    final MosqueSearchLocation? fallback = await _storedLocationFallback();
    if (fallback != null) {
      return fallback;
    }
    throw const MosqueLocationException('Nearest_Mosque_Location_Disabled');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied) {
    final MosqueSearchLocation? fallback = await _storedLocationFallback();
    if (fallback != null) {
      return fallback;
    }
    throw const MosqueLocationException('Nearest_Mosque_Permission_Denied');
  }

  if (permission == LocationPermission.deniedForever) {
    final MosqueSearchLocation? fallback = await _storedLocationFallback();
    if (fallback != null) {
      return fallback;
    }
    throw const MosqueLocationException(
      'Nearest_Mosque_Permission_Denied_Forever',
    );
  }

  try {
    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    await _storeLastKnownLocation(position.latitude, position.longitude);
    return MosqueSearchLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      fromFallback: false,
    );
  } catch (_) {
    final Position? lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      await _storeLastKnownLocation(lastKnown.latitude, lastKnown.longitude);
      return MosqueSearchLocation(
        latitude: lastKnown.latitude,
        longitude: lastKnown.longitude,
        fromFallback: true,
      );
    }

    final MosqueSearchLocation? fallback = await _storedLocationFallback();
    if (fallback != null) {
      return fallback;
    }

    throw const MosqueLocationException('Nearest_Mosque_Location_Unavailable');
  }
}

Future<MosqueSearchResult> findNearbyMosques({
  required double latitude,
  required double longitude,
  required int initialRadiusMeters,
}) async {
  // final List<int> radii = _progressiveRadii(initialRadiusMeters);
  List<MosquePlace> bestResults = <MosquePlace>[];
  int usedRadius = initialRadiusMeters;

  print('Querying Overpass API with radius: $usedRadius meters');
  final List<MosquePlace> mosques = await _queryOverpass(
    latitude: latitude,
    longitude: longitude,
    radiusMeters: usedRadius,
  );
  bestResults = mosques;

  return MosqueSearchResult(mosques: bestResults, radiusMeters: usedRadius);
}

String formatMosqueDistance(double distanceMeters) {
  if (distanceMeters < 1000) {
    return '${distanceMeters.round()} m';
  }
  return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}

Future<List<MosquePlace>> _queryOverpass({
  required double latitude,
  required double longitude,
  required int radiusMeters,
}) async {
  final Uri uri = Uri.parse('https://overpass-api.de/api/interpreter');
  final String query =
      '''
      [out:json][timeout:25];
      (
        node["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters, $latitude, $longitude);
        way["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters, $latitude, $longitude);
        relation["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters, $latitude, $longitude);
      );
      out center tags;
      ''';

  final http.Response response = await http
      .post(uri,
         headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': '*/*',
          'User-Agent': 'Muslim/1.0 (bssam2012@gmail.com)'},
          body: {'data': query},
          encoding: Encoding.getByName('utf-8'),)
      .timeout(const Duration(seconds: 30));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    print('Overpass error body: ${response.body} and status code: ${response.statusCode}'); 
    throw Exception('Overpass returned ${response.statusCode}');
  }

  final Map<String, dynamic> jsonData =
      jsonDecode(response.body) as Map<String, dynamic>;
  final List<dynamic> elements = jsonData['elements'] as List<dynamic>? ?? [];
  final Map<String, MosquePlace> deduped = <String, MosquePlace>{};

  for (final dynamic item in elements) {
    if (item is! Map<String, dynamic>) {
      continue;
    }

    final Map<String, dynamic> tags = item['tags'] as Map<String, dynamic>? ?? {};
  
    // Add this check after extracting tags
    final bool hasWorship = tags['amenity'] == 'place_of_worship' && tags['religion'] == 'muslim';
    if (!hasWorship) continue;
    final String type = item['type']?.toString() ?? 'element';
    final String id = '$type/${item['id']}';
    final double? itemLatitude = _elementLatitude(item);
    final double? itemLongitude = _elementLongitude(item);

    if (itemLatitude == null || itemLongitude == null) {
      continue;
    }

    final String name =
        _stringTag(tags, 'name') ??
        _stringTag(tags, 'name:en') ??
        _stringTag(tags, 'name:ar') ??
        _stringTag(tags, 'name:ur') ??
        'Nearest_Mosque_Unknown_Name';
    final String address = _addressFromTags(tags);
    final double distanceMeters = _haversineDistanceMeters(
      latitude,
      longitude,
      itemLatitude,
      itemLongitude,
    );
    final String dedupeKey = name == 'Nearest_Mosque_Unknown_Name'
        ? id
        : '${name.toLowerCase()}-${itemLatitude.toStringAsFixed(5)}-${itemLongitude.toStringAsFixed(5)}';
    deduped[dedupeKey] = MosquePlace(
      id: id,
      name: name,
      latitude: itemLatitude,
      longitude: itemLongitude,
      distanceMeters: distanceMeters,
      address: address,
    );
  }

  final List<MosquePlace> mosques = deduped.values.toList()
    ..sort(
      (MosquePlace a, MosquePlace b) =>
          a.distanceMeters.compareTo(b.distanceMeters),
    );
  return mosques;
}

double? _elementLatitude(Map<String, dynamic> element) {
  final dynamic lat = element['lat'] ?? (element['center']?['lat']);
  if (lat is num) {
    return lat.toDouble();
  }
  return null;
}

double? _elementLongitude(Map<String, dynamic> element) {
  final dynamic lon = element['lon'] ?? (element['center']?['lon']);
  if (lon is num) {
    return lon.toDouble();
  }
  return null;
}

String? _stringTag(Map<String, dynamic> tags, String key) {
  final dynamic value = tags[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String _addressFromTags(Map<String, dynamic> tags) {
  final List<String> parts = <String>[
    if (_stringTag(tags, 'addr:housenumber') != null)
      _stringTag(tags, 'addr:housenumber')!,
    if (_stringTag(tags, 'addr:housename') != null)
      _stringTag(tags, 'addr:housename')!,
    if (_stringTag(tags, 'addr:street') != null)
      _stringTag(tags, 'addr:street')!,
    if (_stringTag(tags, 'addr:city') != null) _stringTag(tags, 'addr:city')!,
    if (_stringTag(tags, 'addr:postcode') != null)
      _stringTag(tags, 'addr:postcode')!,
  ];
  return parts.join(', ');
}

double _haversineDistanceMeters(
  double startLatitude,
  double startLongitude,
  double endLatitude,
  double endLongitude,
) {
  const double earthRadiusMeters = 6371000;
  final double lat1 = _degreesToRadians(startLatitude);
  final double lat2 = _degreesToRadians(endLatitude);
  final double deltaLat = _degreesToRadians(endLatitude - startLatitude);
  final double deltaLon = _degreesToRadians(endLongitude - startLongitude);
  final double a =
      sin(deltaLat / 2) * sin(deltaLat / 2) +
      cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _degreesToRadians(double degrees) => degrees * pi / 180;

Future<void> _storeLastKnownLocation(double latitude, double longitude) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_lastKnownLatitudeKey, latitude);
  await prefs.setDouble(_lastKnownLongitudeKey, longitude);
}

Future<MosqueSearchLocation?> _storedLocationFallback() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final double? latitude = prefs.getDouble(_lastKnownLatitudeKey);
  final double? longitude = prefs.getDouble(_lastKnownLongitudeKey);
  if (latitude == null || longitude == null) {
    return null;
  }
  return MosqueSearchLocation(
    latitude: latitude,
    longitude: longitude,
    fromFallback: true,
  );
}
