import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const TaxiSpotApp());

class TaxiSpot {
  final String name;
  final LatLng point;
  final int score;
  final String note;
  const TaxiSpot(this.name, this.point, this.score, this.note);
}

const spots = <TaxiSpot>[
  TaxiSpot('Berlin Hauptbahnhof', LatLng(52.5251, 13.3694), 92, 'محطة رئيسية • حركة قطارات مرتفعة'),
  TaxiSpot('Alexanderplatz', LatLng(52.5219, 13.4132), 84, 'سياحة • فنادق • مواصلات'),
  TaxiSpot('Zoologischer Garten', LatLng(52.5073, 13.3326), 78, 'محطة قطارات • تسوق • فنادق'),
  TaxiSpot('Potsdamer Platz', LatLng(52.5096, 13.3760), 73, 'فنادق • مطاعم • فعاليات'),
  TaxiSpot('BER Airport', LatLng(52.3667, 13.5033), 88, 'مطار • رحلات وصول ومغادرة'),
];

class TaxiSpotApp extends StatelessWidget {
  const TaxiSpotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaxiSpot Berlin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
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

  Future<void> _locateMe() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.denied ||
    permission == LocationPermission.deniedForever) {
  return;
}
        final p = await Geolocator.getCurrentPosition();
    final point = LatLng(p.latitude, p.longitude);
    setState(() => _driver = point);
    _mapController.move(point, 14);
  }

  Future<void> _navigate(TaxiSpot spot) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${spot.point.latitude},${spot.point.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color _scoreColor(int score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final best = [...spots]..sort((a, b) => b.score.compareTo(a.score));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TaxiSpot Berlin', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('أفضل مواقع التاكسي الآن', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(52.5200, 13.4050),
              initialZoom: 11.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.taxispot.berlin',
              ),
              MarkerLayer(
                markers: [
                  ...spots.map((s) => Marker(
                    point: s.point,
                    width: 58,
                    height: 58,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = s),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _scoreColor(s.score),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
                        ),
                        alignment: Alignment.center,
                        child: Text('${s.score}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )),
                  if (_driver != null)
                    Marker(
                      point: _driver!,
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.local_taxi, color: Colors.black, size: 42),
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
          if (_selected != null)
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(child: Text(_selected!.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        Chip(label: Text('${_selected!.score}/100')),
                      ]),
                      Text(_selected!.note, textDirection: TextDirection.rtl),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _navigate(_selected!),
                            icon: const Icon(Icons.navigation),
                            label: const Text('خذني إلى هناك'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('تم تسجيل زبون في ${_selected!.name}')),
                              );
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('حصلت على زبون'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text('الأفضل الآن: ${best.first.name} (${best.first.score})',
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
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
