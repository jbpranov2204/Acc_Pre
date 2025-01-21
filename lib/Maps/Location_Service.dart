import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  Future<Position> determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw "Location services are disabled.";
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw "Location permissions are denied.";
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw "Location permissions are permanently denied.";
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<String> reverseGeocode(double lat, double lon) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null) {
          return data['display_name'];
        }
      }
      debugPrint('Reverse geocoding failed, status: ${response.statusCode}');
      return "Current Location";
    } catch (e) {
      debugPrint("Error in reverse geocoding: $e");
      return "Current Location";
    }
  }

  // Updated to be more precise and efficient
  List<Map<String, double>> calculateSurroundingLocations(
      double lat, double lon) {
    const int numPoints = 8;
    const double radius = 0.001; // Radius for surrounding locations
    List<Map<String, double>> locations = [];
    double angleIncrement = 2 * pi / numPoints;
    for (int i = 0; i < numPoints; i++) {
      double angle = i * angleIncrement;
      double newLat = lat + radius * cos(angle);
      double newLon = lon + radius * sin(angle);
      locations.add({'latitude': newLat, 'longitude': newLon});
    }
    return locations;
  }

  void printSavedLocation(Map<String, dynamic> locationData) {
    debugPrint("--- Saved Location ---");
    debugPrint("Place Name: ${locationData['place_name']}");
    debugPrint("Latitude: ${locationData['latitude']}");
    debugPrint("Longitude: ${locationData['longitude']}");
    debugPrint("Surrounding Locations:");
    if (locationData['surrounding_locations'] != null &&
        locationData['surrounding_locations'] is List) {
      for (var loc in (locationData['surrounding_locations'] as List)) {
        debugPrint(
            "  - Latitude: ${loc['latitude']}, Longitude: ${loc['longitude']}");
      }
    } else {
      debugPrint("  No surrounding locations available.");
    }
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    final lat1 = point1.latitude * (pi / 180);
    final lon1 = point1.longitude * (pi / 180);
    final lat2 = point2.latitude * (pi / 180);
    final lon2 = point2.longitude * (pi / 180);
    final dlon = lon2 - lon1;
    final dlat = lat2 - lat1;
    final a =
        pow(sin(dlat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dlon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
}
