import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SearchService {
  Future<List<dynamic>> searchPlaces(String query) async {
    final url =
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=2';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint(
            "Failed to load search results. Status code: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error during search request: $e");
      return [];
    }
  }
}