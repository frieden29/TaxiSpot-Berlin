import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

enum BerlinPlaceType {
  hotel,
  event,
  theatre,
  conference,
}

class BerlinPlace {
  final String id;
  final String name;
  final LatLng location;
  final BerlinPlaceType type;

  const BerlinPlace({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
  });
}

class BerlinPlacesLoader {
  static Future<List<BerlinPlace>> load() async {
    final text = await rootBundle.loadString('lib/export2.geojson');
    final data = jsonDecode(text) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];

    final places = <BerlinPlace>[];
    final seenIds = <String>{};

    for (final item in features) {
      if (item is! Map<String, dynamic>) continue;

      final properties =
          item['properties'] as Map<String, dynamic>? ?? {};

      final geometry = item['geometry'];
      if (geometry is! Map<String, dynamic>) continue;

      final coordinates = _coordinates(geometry);
      if (coordinates == null) continue;

      final longitude = coordinates[0];
      final latitude = coordinates[1];

      if (!longitude.isFinite ||
          !latitude.isFinite ||
          longitude < -180 ||
          longitude > 180 ||
          latitude < -90 ||
          latitude > 90) {
        continue;
      }

      final type = _type(properties);
      if (type == null) continue;

      final rawName = properties['name']?.toString().trim();
      final name = rawName == null || rawName.isEmpty
          ? _defaultName(type)
          : rawName;

      final id = item['id']?.toString() ??
          properties['@id']?.toString() ??
          '${latitude}_${longitude}_$name';

      if (!seenIds.add(id)) continue;

      places.add(
        BerlinPlace(
          id: id,
          name: name,
          location: LatLng(latitude, longitude),
          type: type,
        ),
      );
    }

    return places;
  }

  static List<double>? _coordinates(Map<String, dynamic> geometry) {
    final type = geometry['type'];
    final coordinates = geometry['coordinates'];

    if (type == 'Point' && coordinates is List && coordinates.length >= 2) {
      final lon = (coordinates[0] as num?)?.toDouble();
      final lat = (coordinates[1] as num?)?.toDouble();

      if (lon != null && lat != null) return [lon, lat];
    }

    // Polygon and other geometry types need a representative point.
    // Do not guess a location from the first polygon vertex.
    return null;
  }

  static BerlinPlaceType? _type(Map<String, dynamic> p) {
    final tourism = p['tourism']?.toString();
    final amenity = p['amenity']?.toString();
    final leisure = p['leisure']?.toString();
    final building = p['building']?.toString();

    if (tourism == 'hotel' || tourism == 'hostel') {
      return BerlinPlaceType.hotel;
    }

    if (amenity == 'conference_centre') {
      return BerlinPlaceType.conference;
    }

    if (amenity == 'theatre' ||
        amenity == 'concert_hall' ||
        amenity == 'music_venue' ||
        amenity == 'arts_centre') {
      return BerlinPlaceType.theatre;
    }

    if (amenity == 'events_venue' ||
        leisure == 'stadium' ||
        building == 'stadium') {
      return BerlinPlaceType.event;
    }

    return null;
  }

  static String _defaultName(BerlinPlaceType type) {
    switch (type) {
      case BerlinPlaceType.hotel:
        return 'Hotel';
      case BerlinPlaceType.event:
        return 'Veranstaltungsort';
      case BerlinPlaceType.theatre:
        return 'Theater / Musik';
      case BerlinPlaceType.conference:
        return 'Konferenzzentrum';
    }
  }
}