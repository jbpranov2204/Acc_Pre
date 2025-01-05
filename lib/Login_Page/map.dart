import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:http/http.dart' as http;

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _controller = MapController(
    initPosition: GeoPoint(latitude: 11.0, longitude: 76.0),
    
  );

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // Function to fetch latitude and longitude using the Nominatim API
  Future<GeoPoint?> _getGeoPoint(String location) async {
    final String url =
        "https://nominatim.openstreetmap.org/search?q=$location&format=json&limit=1";

    try {
      final response = await http.get(Uri.parse(url), headers: {
        "User-Agent": "FlutterApp/1.0 (flutter_osm_plugin)",
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final double latitude = double.parse(data[0]["lat"]);
          final double longitude = double.parse(data[0]["lon"]);
          return GeoPoint(latitude: latitude, longitude: longitude);
        } else {
          _showError("Location not found: $location");
        }
      } else {
        _showError("Failed to fetch geolocation data: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error fetching geolocation: $e");
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showRoute() async {
    String startLocation = _startController.text.trim();
    String destinationLocation = _destinationController.text.trim();

    if (startLocation.isEmpty || destinationLocation.isEmpty) {
      _showError("Both start and destination fields are required.");
      return;
    }

    try {
      GeoPoint? startPoint = await _getGeoPoint(startLocation);
      GeoPoint? destPoint = await _getGeoPoint(destinationLocation);

      if (startPoint == null || destPoint == null) {
        throw Exception("Invalid location(s). Please try again.");
      }

      // Add markers for start and destination points
      await _controller.addMarker(
        startPoint,
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.location_on, color: Colors.green, size: 48),
        ),
      );
      await _controller.addMarker(
        destPoint,
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.location_on, color: Colors.red, size: 48),
        ),
      );

      // Clear any existing routes
      await _controller.clearAllRoads();

      // Draw route between start and destination
      RoadInfo roadInfo = await _controller.drawRoad(
        startPoint,
        destPoint,
        roadOption: const RoadOption(
          roadColor: Colors.blue,
          roadWidth: 8,
        ),
      ).catchError((e) {
        _showError("Error drawing road: $e");
      });

      // Show route info (distance and duration)
      if (roadInfo.distance != null && roadInfo.duration != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Route Info: Distance - ${roadInfo.distance?.toStringAsFixed(2)} km, "
              "Duration - ${roadInfo.duration?.toStringAsFixed(2)} mins",
            ),
          ),
        );
      }

      // Center the map to fit the route
      await _controller.zoomToBoundingBox(
        BoundingBox.fromGeoPoints([startPoint, destPoint]),
      );
    } catch (e) {
      _showError("Error: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Route Display"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Start Location",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _startController,
                  decoration: const InputDecoration(
                    hintText: "Enter start location (City/Place)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Destination Location",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    hintText: "Enter destination location (City/Place)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _showRoute,
            child: const Text("Show Route"),
          ),
          Expanded(
            child: OSMFlutter(
              controller: _controller,
              osmOption: OSMOption(
                zoomOption: const ZoomOption(
                  initZoom: 12,
                  minZoomLevel: 3,
                  maxZoomLevel: 19,
                ),
                userLocationMarker: UserLocationMaker(
                  personMarker: const MarkerIcon(
                    icon: Icon(Icons.person_pin_circle, color: Colors.blue, size: 48),
                  ),
                  directionArrowMarker: const MarkerIcon(
                    icon: Icon(Icons.navigation, color: Colors.blue, size: 48),
                  ),
                ),
                showDefaultInfoWindow: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _destinationController.dispose();
    _controller.dispose();
    super.dispose();
  }
}