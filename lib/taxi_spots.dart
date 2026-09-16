import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class TaxiSpotData {
  final String name;
  final LatLng point;

  const TaxiSpotData(this.name, this.point);
}

Future<List<TaxiSpotData>> loadTaxiSpots() async {
  final jsonString =
      await rootBundle.loadString('lib/export.geojson');

  final data = jsonDecode(jsonString) as Map<String, dynamic>;
  final features = data['features'] as List<dynamic>;

  final spots = <TaxiSpotData>[];

  for (final feature in features) {
    final item = feature as Map<String, dynamic>;
    final geometry = item['geometry'] as Map<String, dynamic>;
    final properties = item['properties'] as Map<String, dynamic>;

    if (geometry['type'] != 'Point') continue;

    final coordinates = geometry['coordinates'] as List<dynamic>;

    final longitude = (coordinates[0] as num).toDouble();
    final latitude = (coordinates[1] as num).toDouble();

    final name = properties['name']?.toString() ??
        'موقف تاكسي ${spots.length + 1}';

    spots.add(
      TaxiSpotData(name, LatLng(latitude, longitude)),
    );
  }

  return spots;
}