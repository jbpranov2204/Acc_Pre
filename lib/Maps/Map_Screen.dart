import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import 'package:myapp/Maps/Location_Service.dart';
import 'package:myapp/Maps/Marker_Dialog.dart';

import 'package:myapp/Maps/Search_Service.dart';
import 'package:myapp/Maps/Storage_Service.dart';
import 'package:myapp/models/Marker_Data.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // --- Map Variables ---
  final MapController mapController = MapController();
  LatLng? selectedPosition;
  LatLng? mylocation;
  LatLng? draggedPosition;
  LatLng? searchResultPosition;
  bool isDragging = false;

  // --- Marker Variables ---
  final LayerLink _markerLayerLink = LayerLink();
  List<Marker> markers = [];
  List<Markerdata> markerdata = [];

  // --- Search Variables ---
  final TextEditingController searchController = TextEditingController();
  List<dynamic> searchResults = [];
  bool isSearching = false;
  bool isLoadingSearch = false;
  Timer? _debounceTimer;

  // --- Accident Zones Variables ---
  List<CircleMarker> dangerCircles = [];
  List<LatLng> accidentLocations = [];
  double searchRadius = 1000;
  bool showDangerZone = false;

  // --- Weather Variables ---
  late LocationPermission _weatherPermission;
  String _weatherErrorMessage = '';
  List<WeatherData> _weatherData = [];
  bool _isLoadingWeather = false;

  // --- Location Saving Variables ---
  List<Map<String, dynamic>> _savedLocations = [];
  StreamSubscription<Position>? _positionStreamSubscription;

  // --- Services ---
  final LocationService _locationService = LocationService();
  final SearchService _searchService = SearchService();
  final StorageService _storageService = StorageService();

  // --- Weather Functions ---
  Future<void> _checkWeatherPermission() async {
    _weatherPermission = await Geolocator.checkPermission();
    if (_weatherPermission == LocationPermission.denied) {
      _weatherPermission = await Geolocator.requestPermission();
      if (_weatherPermission == LocationPermission.denied) {
        setState(() {
          _weatherErrorMessage =
              'Location permissions are denied. Please enable them in settings.';
        });
        return;
      }
    }
    if (_weatherPermission == LocationPermission.deniedForever) {
      setState(() {
        _weatherErrorMessage =
            'Location permissions are permanently denied. Please enable them in settings.';
      });
      return;
    }
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    if (mylocation == null) {
      setState(() {
        _isLoadingWeather = false;
        _weatherErrorMessage = "No Location Data";
      });
      return;
    }

    setState(() {
      _isLoadingWeather = true;
      _weatherErrorMessage = "";
    });

    // define the coordinates that will be used for the call to the API
    List<List<double>> coordinates = [
      [mylocation!.latitude, mylocation!.longitude], // Current location
      [mylocation!.latitude + 0.05, mylocation!.longitude], // Up
      [mylocation!.latitude - 0.05, mylocation!.longitude], // Down
      [mylocation!.latitude, mylocation!.longitude + 0.05], // Right
      [mylocation!.latitude, mylocation!.longitude - 0.05], // Left
      [mylocation!.latitude + 0.05, mylocation!.longitude + 0.05], // Up Right
      [mylocation!.latitude + 0.05, mylocation!.longitude - 0.05], // Up Left
      [mylocation!.latitude - 0.05, mylocation!.longitude + 0.05], // Down Right
      [mylocation!.latitude - 0.05, mylocation!.longitude - 0.05], // Down Left
    ];

    List<WeatherData> fetchedData = [];
    for (final coord in coordinates) {
      final lat = coord[0];
      final lon = coord[1];
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=647427d5067bdf5e04d92723c31077f6&units=metric';

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          fetchedData.add(WeatherData.fromJson(data));
        } else {
          setState(() {
            _weatherErrorMessage =
                'Failed to load weather data from: $url  ${response.statusCode}';
          });
        }
      } catch (e) {
        setState(() {
          _weatherErrorMessage = 'Error fetching weather data from: $url  $e';
        });
      }
    }
    setState(() {
      _weatherData = fetchedData;
      _isLoadingWeather = false;
    });
  }

  // --- Location Functions ---
  Future<void> showCurrentLocation() async {
    try {
      Position position = await _locationService.determinePosition();
      _updateLocation(position);
      await _checkWeatherPermission();
    } catch (e) {
      debugPrint("Error getting current location: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error getting current location: $e"),
        ));
      }
    }
  }

  void _updateLocation(Position position) {
    final currentLatLng = LatLng(position.latitude, position.longitude);
    mapController.move(currentLatLng, 15);
    setState(() {
      mylocation = currentLatLng;
    });
    debugPrint(
        "Current Location Update: Latitude: ${position.latitude}, Longitude: ${position.longitude}");

    if (showDangerZone) {
      _updateDangerZone();
    }
    _saveCurrentLocationOnUpdate(position);
  }

  Future<void> _saveCurrentLocationOnUpdate(Position position) async {
    final lat = position.latitude;
    final lon = position.longitude;
    String placeName = "Current Location";

    try {
      placeName = await _locationService.reverseGeocode(lat, lon);
    } catch (e) {
      debugPrint("Error reverse geocoding current location: $e");
    }

    _saveLocationForUpdate(lat, lon, placeName);
  }

  Future<void> _saveLocationForUpdate(
      double lat, double lon, String placeName) async {
    final locationData = {
      'place_name': placeName,
      'latitude': lat,
      'longitude': lon,
      'surrounding_locations':
          _locationService.calculateSurroundingLocations(lat, lon)
    };

    _locationService.printSavedLocation(locationData);
    _storageService.saveLocationToJson(locationData);
  }

  // --- Marker Functions ---
  void addMarker(LatLng position, String title, String description) {
    final markerData = Markerdata(
      position: position,
      title: title,
      description: description,
    );
    final marker = Marker(
        point: position,
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () => showMarkerInfo(markerData),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ]),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40,
              )
            ],
          ),
        ));

    setState(() {
      markerdata.add(markerData);
      markers.add(marker);
    });
  }

  void showMarkerDialog(BuildContext context, LatLng position) {
    showDialog(
        context: context,
        builder: (context) => MarkerDialog(
              onMarkerAdded: (title, description) {
                _saveLocation(position.latitude, position.longitude, title)
                    .then((value) => {
                          addMarker(position, title, description),
                        });
              },
            ));
  }

  void showMarkerInfo(Markerdata markerData) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(markerData.title),
              content: Text(markerData.description),
              actions: [
                IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close))
              ],
            ));
  }

  // --- Search Functions ---
  Future<void> searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isLoadingSearch = false;
      });
      return;
    }

    setState(() {
      isLoadingSearch = true;
    });

    try {
      final results = await _searchService.searchPlaces(query);
      if (mounted) {
        setState(() {
          searchResults = results;
          isLoadingSearch = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          searchResults = [];
          isLoadingSearch = false;
        });
      }
      debugPrint("Error during search request: $e");
    }
  }

  void moveToLocation(double lat, double lon) {
    LatLng location = LatLng(lat, lon);
    mapController.move(location, 15);
    setState(() {
      selectedPosition = location;
      searchResultPosition = location;
      searchResults = [];
      isSearching = false;
      searchController.clear();

      if (showDangerZone) {
        _checkAndUpdateAccidentDisplay(location);
      }
      _checkWeatherPermission();
    });
  }

  // --- Accident Zones Functions ---
  void _generateRandomAccidents() {
    accidentLocations = [];
    final random = Random();

    if (mylocation != null) {
      for (int i = 0; i < 5; i++) {
        final angle = random.nextDouble() * 2 * pi;
        final distance = random.nextDouble() * searchRadius;

        final latRad = mylocation!.latitude * (pi / 180);
        final lonRad = mylocation!.longitude * (pi / 180);
        final newLat = asin(sin(latRad) * cos(distance / 6371000) +
            cos(latRad) * sin(distance / 6371000) * cos(angle));
        final newLng = lonRad +
            atan2(sin(angle) * sin(distance / 6371000) * cos(latRad),
                cos(distance / 6371000) - sin(latRad) * sin(newLat));

        final newLatLng = LatLng(newLat * (180 / pi), newLng * (180 / pi));
        accidentLocations.add(newLatLng);
      }
    }
    _updateDangerZone();
  }

  void _updateDangerZone() {
    if (mylocation == null) return;

    final newDangerCircles = <CircleMarker>[];
    // Add the big search circle
    newDangerCircles.add(CircleMarker(
      point: mylocation!,
      radius: searchRadius,
      useRadiusInMeter: true,
      color: Colors.red.withOpacity(0.2),
      borderColor: Colors.red,
      borderStrokeWidth: 2,
    ));

    // Add marker circles
    for (var location in accidentLocations) {
      newDangerCircles.add(CircleMarker(
        point: location,
        radius: 10,
        color: Colors.red,
        borderColor: Colors.white,
        borderStrokeWidth: 2,
      ));
    }

    setState(() {
      dangerCircles = newDangerCircles;
    });
  }

  void _checkAndUpdateAccidentDisplay(LatLng location) {
    if (mylocation == null) return;

    final distance = _locationService.calculateDistance(location, mylocation!);
    final newCircles = <CircleMarker>[];
    if (distance <= searchRadius) {
      _updateDangerZone();
    } else {
      newCircles.add(CircleMarker(
        point: location,
        radius: searchRadius,
        useRadiusInMeter: true,
        color: Colors.red.withOpacity(0.2),
        borderColor: Colors.red,
        borderStrokeWidth: 2,
      ));
      setState(() {
        dangerCircles = newCircles;
      });
    }
  }

  // --- Location Saving Functions ---
  Future<void> _saveLocation(double lat, double lon, String placeName) async {
    try {
      final locationData = {
        'place_name': placeName,
        'latitude': lat,
        'longitude': lon,
        'surrounding_locations':
            _locationService.calculateSurroundingLocations(lat, lon)
      };

      setState(() {
        _savedLocations.add(locationData);
      });

      await _storageService.saveLocations(_savedLocations);

      debugPrint('Location saved to in-memory list: $locationData');
      // Print location data including surrounding locations after saving
      _locationService.printSavedLocation(locationData);
      _showSavedLocationMessage(placeName);
    } catch (e) {
      debugPrint('Error saving location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error saving location: $e"),
        ));
      }
    }
  }

  // Loading Functions
  Future<void> _loadSavedLocations() async {
    final loadedLocations = await _storageService.loadSavedLocations();
    if (mounted) {
      setState(() {
        _savedLocations = loadedLocations;
      });
      debugPrint("Loaded Locations: $_savedLocations");
    }

    _storageService.loadAutoSavedLocations();
  }

  void _showSavedLocationMessage(String locationName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$locationName saved successfully!'),
      ),
    );
  }

  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    _loadSavedLocations();

    searchController.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        searchPlaces(searchController.text);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCurrentLocation();
    });

    _positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high, distanceFilter: 10))
        .listen((Position position) {
      _updateLocation(position);
    }, onError: (error) {
      debugPrint('Error in position stream: $error');
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _debounceTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
                initialZoom: 13,
                onTap: (TapPosition, latlng) {
                  setState(() {
                    selectedPosition = latlng;
                    draggedPosition = selectedPosition;
                  });
                }),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              if (draggedPosition != null)
                MarkerLayer(markers: [
                  Marker(
                      point: draggedPosition!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.indigo,
                        size: 40,
                      )),
                ]),
              if (searchResultPosition != null)
                MarkerLayer(markers: [
                  Marker(
                      point: searchResultPosition!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
                      )),
                ]),
              if (mylocation != null)
                MarkerLayer(markers: [
                  Marker(
                      point: mylocation!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 40,
                      )),
                ]),
              CircleLayer(circles: dangerCircles),
              CompositedTransformFollower(
                link: _markerLayerLink,
                child: MarkerLayer(markers: markers),
              ),
              if (showDangerZone && accidentLocations.isNotEmpty)
                MarkerLayer(
                  markers: accidentLocations
                      .map((latlng) => Marker(
                            point: latlng,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                          ))
                      .toList(),
                ),
            ],
          ),
          Positioned(
              top: 40,
              left: 15,
              right: 15,
              child: Column(
                children: [
                  SizedBox(
                    height: 55,
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                          hintText: "Search Place...",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: isSearching
                              ? IconButton(
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() {
                                      isSearching = false;
                                      searchResults = [];
                                    });
                                  },
                                  icon: const Icon(Icons.clear))
                              : null),
                      onTap: () {
                        setState(() {
                          isSearching = true;
                        });
                      },
                    ),
                  ),
                  if (isSearching)
                    Container(
                      color: Colors.white,
                      child: isLoadingSearch
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : searchResults.isNotEmpty
                              ? ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: searchResults.length,
                                  itemBuilder: (ctx, index) {
                                    final place = searchResults[index];
                                    return ListTile(
                                      key: ValueKey(place[
                                          'place_id']), // Unique key for each list tile
                                      title: Text(place['display_name']),
                                      onTap: () {
                                        final lat = double.parse(place['lat']);
                                        final lon = double.parse(place['lon']);
                                        moveToLocation(lat, lon);
                                      },
                                    );
                                  })
                              : const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('No Results Found'),
                                ),
                    ),
                ],
              )),
          isDragging == false
              ? Positioned(
                  bottom: 20,
                  left: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      setState(() {
                        isDragging = true;
                      });
                    },
                    child: const Icon(Icons.add_location),
                  ))
              : Positioned(
                  bottom: 20,
                  left: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      setState(() {
                        isDragging = false;
                      });
                    },
                    child: const Icon(Icons.wrong_location),
                  )),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.indigo,
                  onPressed: showCurrentLocation,
                  child: const Icon(Icons.location_searching_outlined),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: FloatingActionButton(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      setState(() {
                        showDangerZone = !showDangerZone;
                        if (showDangerZone) {
                          _generateRandomAccidents();
                        } else {
                          dangerCircles = [];
                          accidentLocations = [];
                        }
                      });
                    },
                    child: Icon(showDangerZone
                        ? Icons.visibility_off
                        : Icons.visibility),
                  ),
                ),
                if (isDragging)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: FloatingActionButton(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      onPressed: () {
                        if (draggedPosition != null) {
                          showMarkerDialog(context, draggedPosition!);
                        }
                        setState(() {
                          isDragging = false;
                          draggedPosition = null;
                        });
                      },
                      child: const Icon(Icons.location_searching_outlined),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: FloatingActionButton(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      _checkWeatherPermission();
                      _showWeatherDialog(context);
                    },
                    child: const Icon(Icons.sunny),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showWeatherDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Weather Information'),
              content: _isLoadingWeather
                  ? const Center(child: CircularProgressIndicator())
                  : _weatherErrorMessage.isNotEmpty
                      ? Text(_weatherErrorMessage)
                      : SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _weatherData.length,
                            itemBuilder: (context, index) {
                              final weather = _weatherData[index];
                              return ListTile(
                                title: Text(weather.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Temperature: ${weather.main.temp}°C'),
                                    Text(
                                        'Condition: ${weather.weather.isNotEmpty ? weather.weather[0].description : "Unknown"}'),
                                    Text('Humidity: ${weather.main.humidity}%'),
                                    Text(
                                        'Wind Speed: ${weather.wind.speed} m/s'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
              actions: [
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ));
  }
}

class WeatherData {
  final String name;
  final MainData main;
  final List<WeatherDescription> weather;
  final WindData wind;

  WeatherData({
    required this.name,
    required this.main,
    required this.weather,
    required this.wind,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      name: json['name'],
      main: MainData.fromJson(json['main']),
      weather: (json['weather'] as List)
          .map((item) => WeatherDescription.fromJson(item))
          .toList(),
      wind: WindData.fromJson(json['wind']),
    );
  }
}

class MainData {
  final double temp;
  final int humidity;

  MainData({required this.temp, required this.humidity});

  factory MainData.fromJson(Map<String, dynamic> json) {
    return MainData(
      temp: json['temp'].toDouble(),
      humidity: json['humidity'],
    );
  }
}

class WeatherDescription {
  final String description;

  WeatherDescription({required this.description});

  factory WeatherDescription.fromJson(Map<String, dynamic> json) {
    return WeatherDescription(
      description: json['description'],
    );
  }
}

class WindData {
  final double speed;

  WindData({required this.speed});

  factory WindData.fromJson(Map<String, dynamic> json) {
    return WindData(
      speed: json['speed'].toDouble(),
    );
  }
}
