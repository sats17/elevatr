import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Earth Map in Flutter',
      debugShowCheckedModeBanner: false,
      home: MapPage(),
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  Future<double?> fetchElevation(double lat, double lon) async {
    final url = Uri.parse('https://api.open-elevation.com/api/v1/lookup?locations=$lat,$lon');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elevation = data['results'][0]['elevation'];
        return elevation.toDouble();
      } else {
        print('Error fetching elevation: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🌍 Earth Map')),
      body: FlutterMap(
      options: MapOptions(
        center: LatLng(0, 0),
        zoom: 2.0,
        minZoom: 1.0,
        maxZoom: 18.0,
        onTap: (tapPosition, point) async {
          final elevation = await fetchElevation(point.latitude, point.longitude);
          if (elevation != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Elevation: ${elevation.toStringAsFixed(2)} meters')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not fetch elevation')),
            );
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.earth_map',
        ),
      ],
    ),

    );
  }
}
