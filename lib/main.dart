import 'dart:convert'; // Used for decoding JSON responses
import 'package:flutter/material.dart'; // Flutter UI framework
import 'package:flutter_map/flutter_map.dart'; // Flutter map plugin for OpenStreetMap
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart'; // Used for LatLng class (coordinates)
import 'package:http/http.dart' as http; // HTTP package to make API requests

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Elevation Map',
      debugShowCheckedModeBanner: false,
      home: MapPage(),
    );
  }
}

class MapLayerOption {
  final String name;
  final String urlTemplate;

  MapLayerOption({required this.name, required this.urlTemplate});
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();

  List<LatLng> selectedPoints = [];
  Map<LatLng, double> elevationData = {};
  List<Polyline> polylines = [];
  List<Marker> markers = [];

  final List<MapLayerOption> mapLayers = [
    MapLayerOption(
      name: 'OpenStreetMap',
      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    MapLayerOption(
      name: 'Stamen Toner',
      urlTemplate: 'https://stamen-tiles.a.ssl.fastly.net/toner/{z}/{x}/{y}.png',
    ),
    MapLayerOption(
      name: 'Stamen Terrain',
      urlTemplate: 'https://stamen-tiles.a.ssl.fastly.net/terrain/{z}/{x}/{y}.png',
    ),
  ];

  late MapLayerOption selectedLayer;

  @override
  void initState() {
    super.initState();
    selectedLayer = mapLayers[0];
  }

  Future<double?> fetchElevation(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.open-elevation.com/api/v1/lookup?locations=$lat,$lon',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elevation = data['results'][0]['elevation'];
        return elevation.toDouble();
      }
    } catch (e) {
      print('Elevation fetch error: $e');
    }
    return null;
  }

  void handleTap(LatLng point) async {
    final elevation = await fetchElevation(point.latitude, point.longitude);

    if (elevation != null) {
      setState(() {
        markers.add(
          Marker(
            point: point,
            width: 30,
            height: 30,
            builder: (ctx) => const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 30,
            ),
          ),
        );

        elevationData[point] = elevation;

        // Polyline drawing disabled
        /*
        selectedPoints.add(point);
        if (selectedPoints.length == 2) {
          polylines.add(
            Polyline(
              points: selectedPoints,
              color: Colors.blue,
              strokeWidth: 4.0,
            ),
          );
          selectedPoints = [];
        }
        */
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch elevation')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏔️ Elevation Map')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  center: LatLng(0, 0),
                  zoom: 2.0,
                  interactiveFlags: InteractiveFlag.all,
                  onTap: (tapPosition, point) {
                    handleTap(point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: selectedLayer.urlTemplate,
                    subdomains: ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.elevation_map',
                  ),

                  MarkerLayer(markers: markers),

                  PolylineLayer(polylines: polylines),

                  Builder(
                    builder: (ctx) {
                      final map = FlutterMapState.maybeOf(ctx)!;
                      return Stack(
                        children: elevationData.entries.map((entry) {
                          final point = entry.key;
                          final elevation = entry.value;

                          final pixelPoint = map.project(point) - map.pixelOrigin;

                          return Positioned(
                            left: pixelPoint.x.toDouble() - 40,
                            top: pixelPoint.y.toDouble() - 50,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black87),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${elevation.toStringAsFixed(1)} m',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),

              Positioned(
                top: 10,
                right: 10,
                child: Column(
                  children: [
                    FloatingActionButton(
                      mini: true,
                      heroTag: 'zoom-in',
                      onPressed: () {
                        mapController.move(
                          mapController.center,
                          mapController.zoom + 1,
                        );
                      },
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      mini: true,
                      heroTag: 'zoom-out',
                      onPressed: () {
                        mapController.move(
                          mapController.center,
                          mapController.zoom - 1,
                        );
                      },
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 10,
                left: 10,
                child: FloatingActionButton(
                  mini: true,
                  heroTag: 'layer-btn',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return ListView(
                          shrinkWrap: true,
                          children: mapLayers.map((layer) {
                            return ListTile(
                              title: Text(layer.name),
                              selected: layer == selectedLayer,
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  selectedLayer = layer;
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                  child: const Icon(Icons.layers),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
