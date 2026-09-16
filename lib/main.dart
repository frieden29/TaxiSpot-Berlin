import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'taxi_spots.dart';

void main() => runApp(const TaxiSpotApp());

class TaxiSpot {
  final String name;
  final LatLng point;
  final int? score;
  final String note;

  const TaxiSpot(
    this.name,
    this.point,
    this.score,
    this.note,
  );
}

// These five locations and their scores are examples, not live demand data.
const spots = <TaxiSpot>[
  TaxiSpot(
    'Berlin Hauptbahnhof',
    LatLng(52.5251, 13.3694),
    92,
    'Hauptbahnhof • Beispielbewertung',
  ),
  TaxiSpot(
    'Alexanderplatz',
    LatLng(52.5219, 13.4132),
    84,
    'Tourismus • Beispielbewertung',
  ),
  TaxiSpot(
    'Zoologischer Garten',
    LatLng(52.5073, 13.3326),
    78,
    'Bahnhof • Beispielbewertung',
  ),
  TaxiSpot(
    'Potsdamer Platz',
    LatLng(52.5096, 13.3760),
    73,
    'Hotels • Beispielbewertung',
  ),
  TaxiSpot(
    'BER Airport',
    LatLng(52.3667, 13.5033),
    88,
    'Flughafen • Beispielbewertung',
  ),
];

class TaxiSpotApp extends StatelessWidget {
  const TaxiSpotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaxiSpot Berlin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
        ),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  LatLng? _driver;
  TaxiSpot? _selected = spots.first;

  List<TaxiSpot> _allSpots = List.of(spots);

  bool _loading = true;
  String? _loadError;
  double? _temperature;
  double? _precipitation;
  String? _berlinTime;
  String? _weatherError;
  bool _weatherLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllSpots();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    if (mounted) {
      setState(() {
        _weatherLoading = true;
        _weatherError = null;
      });
    }
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '52.52',
        'longitude': '13.405',
        'current': 'temperature_2m,precipitation',
        'timezone': 'Europe/Berlin',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Weather HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;
      final time = DateTime.parse(current['time'] as String);
      if (!mounted) return;
      setState(() {
        _temperature = (current['temperature_2m'] as num).toDouble();
        _precipitation = (current['precipitation'] as num).toDouble();
        _berlinTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        _weatherLoading = false;
      });
    } catch (e) {
      debugPrint('Weather error: $e');
      if (!mounted) return;
      setState(() {
        _weatherLoading = false;
        _weatherError = 'Wetterdaten konnten nicht geladen werden';
      });
    }
  }

  Future<void> _loadAllSpots() async {
    try {
      final imported = await loadTaxiSpots();

      if (!mounted) return;

      final importedSpots = imported.map((spot) {
        return TaxiSpot(
          spot.name,
          spot.point,
          null,
          'Taxistand in OpenStreetMap • Nachfrage unbekannt',
        );
      }).toList();

      setState(() {
        _allSpots = [
          ...importedSpots,
          ...spots,
        ];

        if (_allSpots.isNotEmpty) {
          _selected = _allSpots.first;
        }

        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      debugPrint('Error loading taxi spots: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadError = 'Importierte Taxistände konnten nicht geladen werden';
      });
    }
  }

  Future<void> _locateMe() async {
    try {
      final enabled =
          await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        _showMessage('Bitte aktiviere die Standortdienste (GPS)');
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Standortberechtigung wurde nicht erteilt');
        return;
      }

      final p = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      final point = LatLng(
        p.latitude,
        p.longitude,
      );

      setState(() {
        _driver = point;
      });

      _mapController.move(point, 14);
    } catch (e) {
      debugPrint('Location error: $e');
      _showMessage('Dein Standort konnte nicht ermittelt werden');
    }
  }

  Future<void> _navigate(TaxiSpot spot) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${spot.point.latitude},${spot.point.longitude}',
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showMessage('Navigation konnte nicht geöffnet werden');
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      _showMessage('Navigation konnte nicht geöffnet werden');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _scoreColor(int? score) {
    if (score == null) return Colors.blue;
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  List<Marker> _buildTaxiMarkers() {
    return _allSpots.map((spot) {
      return Marker(
        point: spot.point,
        width: 46,
        height: 46,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selected = spot;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: _scoreColor(spot.score),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 4,
                  color: Colors.black26,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: spot.score == null
                ? const Icon(
                    Icons.local_taxi,
                    color: Colors.white,
                    size: 23,
                  )
                : Text(
                    '${spot.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      );
    }).toList();
  }

  Widget _weatherBanner() {
    if (_weatherLoading) {
      return const Text('Berliner Wetter wird geladen ...');
    }
    if (_weatherError != null) {
      return Text(_weatherError!);
    }
    final rain = _precipitation == null
        ? 'Niederschlag nicht verfügbar'
        : _precipitation! > 0
            ? 'Niederschlag: ${_precipitation!.toStringAsFixed(1)} mm'
            : 'Kein Niederschlag gemeldet';
    return Text(
      'Berlin · Wetterstand ${_berlinTime ?? '--:--'} Uhr  •  '
      '${_temperature?.toStringAsFixed(1) ?? '--'}°C  •  $rain',
      style: const TextStyle(fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final demoSpots = _allSpots
        .where((spot) => spot.score != null)
        .toList()
      ..sort(
        (a, b) => b.score!.compareTo(a.score!),
      );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TaxiSpot Berlin',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _loading
                  ? 'Taxistände werden geladen ...'
                  : '${_allSpots.length} Standorte auf der Karte',
              style: const TextStyle(fontSize: 12),
            ),
            _weatherBanner(),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(52.5200, 13.4050),
              initialZoom: 11.5,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.taxispot.berlin',
              ),

              // Group nearby taxi stands into clusters.
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 60,
                  size: const Size(48, 48),
                  markers: _buildTaxiMarkers(),
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 5,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${markers.length}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Driver location marker is separate from taxi stand clusters.
              if (_driver != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _driver!,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.black,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          Positioned(
            right: 14,
            top: 14,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              onPressed: _locateMe,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location),
            ),
          ),

          if (_loading)
            const Positioned(
              left: 14,
              top: 14,
              child: Chip(
                label: Text('Taxistände werden geladen ...'),
              ),
            ),

          if (_loadError != null)
            Positioned(
              left: 14,
              top: 14,
              child: Chip(
                label: Text(_loadError!),
              ),
            ),

          if (_selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selected!.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              _selected!.score == null
                                  ? 'Nachfrage unbekannt'
                                  : 'Beispielwert ${_selected!.score}/100',
                            ),
                          ),
                        ],
                      ),

                      Text(
                        _selected!.note,
                        textDirection: TextDirection.ltr,
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _navigate(_selected!),
                              icon: const Icon(
                                Icons.navigation,
                              ),
                              label: const Text(
                                'Route starten',
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _showMessage(
                                  'Fahrgast bei ${_selected!.name} erfasst',
                                );
                              },
                              icon: const Icon(
                                Icons.check_circle,
                              ),
                              label: const Text(
                                'Fahrgast aufgenommen',
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (demoSpots.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Höchster Beispielwert: '
                          '${demoSpots.first.name} '
                          '(${demoSpots.first.score})',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}