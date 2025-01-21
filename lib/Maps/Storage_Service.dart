import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  Future<void> saveLocations(List<Map<String, dynamic>> savedLocations) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final locationsString = jsonEncode(savedLocations);
      await prefs.setString('saved_locations', locationsString);
    } catch (e) {
      debugPrint("Error while saving locations: $e");
    }
  }

  Future<List<Map<String, dynamic>>> loadSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final locationsString = prefs.getString('saved_locations');

    if (locationsString != null) {
      try {
        final List<dynamic> locationsJson = jsonDecode(locationsString);
        return locationsJson.map((e) => e as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint('Error loading saved locations: $e');
        return [];
      }
    }
    return [];
  }

  Future<void> saveLocationToJson(Map<String, dynamic> locationData) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      List<dynamic> existingLocations = [];
      final existingData = prefs.getString('auto_saved_locations');

      if (existingData != null) {
        existingLocations = jsonDecode(existingData);
      }
      existingLocations.add(locationData);
      final updatedData = jsonEncode(existingLocations);

      await prefs.setString('auto_saved_locations', updatedData);
      debugPrint("Auto location Saved to JSON: $locationData");
    } catch (e) {
      debugPrint("Error saving location to JSON: $e");
    }
  }

  Future<void> loadAutoSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final autoSavedString = prefs.getString('auto_saved_locations');
    if (autoSavedString != null) {
      try {
        final List<dynamic> loadedLocations = jsonDecode(autoSavedString);
        debugPrint("Loaded auto saved Locations: $loadedLocations");
      } catch (e) {
        debugPrint('Error loading auto saved locations: $e');
      }
    }
  }
}
