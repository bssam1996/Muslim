import 'dart:convert';

import 'mosque_utils.dart';

String encodeMosqueSearch(
  MosqueSearchLocation location,
  MosqueSearchResult result,
) => jsonEncode({
  'latitude': location.latitude,
  'longitude': location.longitude,
  'fromFallback': location.fromFallback,
  'radius': result.radiusMeters,
  'mosques': [
    for (final mosque in result.mosques)
      {
        'id': mosque.id,
        'name': mosque.name,
        'latitude': mosque.latitude,
        'longitude': mosque.longitude,
        'distance': mosque.distanceMeters,
        'address': mosque.address,
      },
  ],
});

(MosqueSearchLocation, MosqueSearchResult) decodeMosqueSearch(String body) {
  final raw = jsonDecode(body) as Map;
  double coordinate(Map item, String key, double limit) {
    final value = (item[key] as num).toDouble();
    if (!value.isFinite || value.abs() > limit) {
      throw const FormatException('Invalid coordinate');
    }
    return value;
  }

  final radius = raw['radius'] as int;
  if (radius <= 0 || radius > 25000) {
    throw const FormatException('Invalid radius');
  }
  final location = MosqueSearchLocation(
    latitude: coordinate(raw, 'latitude', 90),
    longitude: coordinate(raw, 'longitude', 180),
    fromFallback: raw['fromFallback'] as bool,
  );
  final mosques = (raw['mosques'] as List).map((value) {
    final item = value as Map;
    final distance = (item['distance'] as num).toDouble();
    if (!distance.isFinite || distance < 0) {
      throw const FormatException('Invalid distance');
    }
    return MosquePlace(
      id: item['id'] as String,
      name: item['name'] as String,
      latitude: coordinate(item, 'latitude', 90),
      longitude: coordinate(item, 'longitude', 180),
      distanceMeters: distance,
      address: item['address'] as String,
    );
  }).toList();
  return (location, MosqueSearchResult(mosques: mosques, radiusMeters: radius));
}
