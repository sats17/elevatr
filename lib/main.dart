// Import core libraries
import 'dart:convert'; // Used for decoding JSON responses
import 'package:flutter/material.dart'; // Flutter UI framework
import 'package:flutter_map/flutter_map.dart'; // Flutter map plugin for OpenStreetMap
import 'package:latlong2/latlong.dart'; // Used for LatLng class (coordinates)
import 'package:http/http.dart' as http; // HTTP package to make API requests

void main() {
  // Entry point of the Flutter app
  runApp(const MyApp());
}

// Root widget of the app
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set up basic Material Design app
    return const MaterialApp(
      title: 'Elevation Map',
      debugShowCheckedModeBanner: false, // Remove debug banner
      home: MapPage(), // Set the home page to MapPage
    );
  }
}

// Main screen showing the map
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // List of selected tap points (used to draw polylines)
  List<LatLng> selectedPoints = [];

  // Map to store each point and its corresponding elevation
  Map<LatLng, double> elevationData = {};

  // List of polylines to draw lines on the map
  List<Polyline> polylines = [];

  // Function to fetch elevation from API based on latitude and longitude
  Future<double?> fetchElevation(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.open-elevation.com/api/v1/lookup?locations=$lat,$lon',
    );

    try {
      // Send GET request to Open Elevation API
      final response = await http.get(url);

      // If response is successful (status code 200)
      if (response.statusCode == 200) {
        // Parse the JSON response
        final data = jsonDecode(response.body);

        // Extract elevation value
        final elevation = data['results'][0]['elevation'];

        // Return elevation as a double
        return elevation.toDouble();
      }
    } catch (e) {
      // Print any error that occurs during the API call
      print('Elevation fetch error: $e');
    }

    // Return null if there was an error or failure
    return null;
  }

  // Function that gets triggered when the map is tapped
  void handleTap(LatLng point) async {
    // Fetch elevation for tapped location
    final elevation = await fetchElevation(point.latitude, point.longitude);

    // If successful
    if (elevation != null) {
      setState(() {
        // Add point to list of selected points
        selectedPoints.add(point);

        // Store elevation value in map for that point
        elevationData[point] = elevation;

        // If two points have been selected, draw a line
        if (selectedPoints.length == 2) {
          // Create a new polyline between the two points
          polylines.add(
            Polyline(
              points: selectedPoints,
              color: Colors.blue, // Line color
              strokeWidth: 4.0,   // Line thickness
            ),
          );

          // Reset selection for next set of taps
          selectedPoints = [];
        }
      });
    } else {
      // If elevation fetch failed, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch elevation')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App bar title
      appBar: AppBar(title: const Text('🏔️ Elevation Map')),

      // Main map body
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(0, 0), // Initial center of the map (equator)
          zoom: 2.0,            // Initial zoom level
          
          // Handle tap on map
          onTap: (tapPosition, point) {
            handleTap(point); // Fetch and show elevation
          },
        ),
        children: [
          // Base map using OpenStreetMap tiles
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'], // Subdomains for faster tile loading
            userAgentPackageName: 'com.example.elevation_map',
          ),

          // Line layer to draw polylines between points
          PolylineLayer(polylines: polylines),

          // Markers showing elevation values at selected points
          MarkerLayer(
            markers: elevationData.entries.map((entry) {
              return Marker(
                point: entry.key, // Location of the marker
                width: 120,
                height: 50,
                builder: (ctx) => Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8), // Background color with opacity
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                    border: Border.all(color: Colors.black54), // Border styling
                  ),
                  child: Text(
                    '${entry.value.toStringAsFixed(1)} m', // Elevation label
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              );
            }).toList(), // Convert map entries to a list of markers
          ),
        ],
      ),
    );
  }
}
