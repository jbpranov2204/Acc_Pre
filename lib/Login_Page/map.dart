import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/Login_Page/markerdata.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  List<Marker> markers = [];
  List<Markerdata> markerdata = [];
  LatLng? selectedPosition;
  LatLng? mylocation;
  LatLng? draggedPosition;
  LatLng? searchResultPosition;
  bool isDragging = false;
  TextEditingController searchController = TextEditingController();
  List<dynamic> searchResults = [];
  bool isSearching = false;
  bool isLoadingSearch = false; // Added for loading state
  StreamSubscription<Position>? _positionStreamSubscription;

  // --- Accident Zones Variables ---
  List<CircleMarker> dangerCircles = [];
  List<LatLng> accidentLocations = [];
  double searchRadius = 1000; // in meters
  bool showDangerZone = false; //toggle to show/hide danger zones
  Timer? _debounceTimer; // Add debounce timer

  // --- Modified determinePosition (Removed error handling within the func )---
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

  // --- Modified showCurrentLocation (Handles async errors)---
  Future<void> showCurrentLocation() async {
    try {
      Position position = await determinePosition();
      _updateLocation(position); // Update location and move camera
    } catch (e) {
      print("Error getting current location: $e");
      // Handle error, display message to user, etc.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error getting current location: $e"),
      ));
    }
  }

  // --- Added _updateLocation (Update Location logic)---
  void _updateLocation(Position position) {
    LatLng currentLatLng = LatLng(position.latitude, position.longitude);
    mapController.move(currentLatLng, 15);
    setState(() {
      mylocation = currentLatLng;
      if (showDangerZone) {
        _updateDangerZone();
      }
    });
  }

  // -- Start New Function for Generate Random Accident Locations --
  void _generateRandomAccidents() {
    accidentLocations = []; //reset old locations
    final random = Random();

    if (mylocation != null) {
      for (int i = 0; i < 5; i++) {
        // Random angle and distance
        final angle = random.nextDouble() * 2 * pi;
        final distance = random.nextDouble() * searchRadius;

        // Convert to radians
        final latRad = mylocation!.latitude * (pi / 180);
        final lonRad = mylocation!.longitude * (pi / 180);
        //calculate new lat and lng
        final newLat = asin(sin(latRad) * cos(distance / 6371000) +
            cos(latRad) * sin(distance / 6371000) * cos(angle));
        final newLng = lonRad +
            atan2(sin(angle) * sin(distance / 6371000) * cos(latRad),
                cos(distance / 6371000) - sin(latRad) * sin(newLat));

        final newLatLng = LatLng(newLat * (180 / pi), newLng * (180 / pi));
        accidentLocations.add(newLatLng);
      }
    }
    _updateDangerZone(); // Update the circles
  }

  // -- End New Function --

  // -- Start New Function for Update DangerZone --
  void _updateDangerZone() {
    dangerCircles = []; //clear old circles
    if (mylocation != null) {
      // Add the big search circle
      dangerCircles.add(CircleMarker(
        point: mylocation!,
        radius: searchRadius,
        useRadiusInMeter: true,
        color: Colors.red.withOpacity(0.2),
        borderColor: Colors.red,
        borderStrokeWidth: 2,
      ));
      // Add marker circles
      for (var location in accidentLocations) {
        dangerCircles.add(CircleMarker(
          point: location,
          radius: 10,
          color: Colors.red,
          borderColor: Colors.white,
          borderStrokeWidth: 2,
        ));
      }
    }
    setState(() {}); // Trigger a rebuild
  }
// -- End New Function --

  void addMarker(LatLng position, String title, String description) {
    setState(() {
      final markerData = Markerdata(
          position: position, title: title, description: description);
      markerdata.add(markerData);
      markers.add(Marker(
          point: position,
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => showMarkerInfo(markerData),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ]),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                )
              ],
            ),
          )));
    });
  }

  void showMarkerDialog(BuildContext context, LatLng position) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Add Marker'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: "Title"),
                  ),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(labelText: "Desc"),
                  )
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('cancel')),
                TextButton(
                    onPressed: () {
                      addMarker(
                          position, titleController.text, descController.text);
                      Navigator.pop(context);
                    },
                    child: Text('Add'))
              ],
            ));
  }

  void showMarkerInfo(Markerdata markerdata) {
    showDialog(
        context: context,
        builder: (Context) => AlertDialog(
              title: Text(markerdata.title),
              content: Text(markerdata.description),
              actions: [
                IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.close))
              ],
            ));
  }

  Future<void> searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isLoadingSearch = false;
      });
      return;
    }

    final url =
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5';

    setState(() {
      isLoadingSearch = true;
    });

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          searchResults = data;
          isLoadingSearch = false;
        });
      } else {
        setState(() {
          searchResults = [];
          isLoadingSearch = false;
        });
        print(
            "Failed to load search results. Status code: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        searchResults = [];
        isLoadingSearch = false;
      });
      print("Error during search request: $e");
    }
  }

  void moveToLocation(double lat, double lon) {
    LatLng location = LatLng(lat, lon);
    mapController.move(location, 15);
    setState(() {
      selectedPosition = location;
      searchResultPosition = location; // Save the search result position
      searchResults = [];
      isSearching = false;
      searchController.clear();

      // Show the accident locations after search
      if (showDangerZone) {
        _checkAndUpdateAccidentDisplay(location);
      }
    });
  }

  //Helper function to check if selected location within danger radius of mylocation
  void _checkAndUpdateAccidentDisplay(LatLng location) {
    if (mylocation == null) return;

    double distance = calculateDistance(location, mylocation!);
    if (distance <= searchRadius) {
      _updateDangerZone(); // if within range then update accident locations
    } else {
      dangerCircles.clear();
      dangerCircles.add(CircleMarker(
        point: location,
        radius: searchRadius,
        useRadiusInMeter: true,
        color: Colors.red.withOpacity(0.2),
        borderColor: Colors.red,
        borderStrokeWidth: 2,
      ));
    }
    setState(() {});
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    double lat1 = point1.latitude * (pi / 180);
    double lon1 = point1.longitude * (pi / 180);
    double lat2 = point2.latitude * (pi / 180);
    double lon2 = point2.longitude * (pi / 180);
    double dlon = lon2 - lon1;
    double dlat = lat2 - lat1;
    double a =
        pow(sin(dlat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dlon / 2), 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      // Debounce search
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        searchPlaces(searchController.text);
      });
    });
    // Get initial location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCurrentLocation();
    });

    // Start listening to location changes
    _positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 10 //update if moved at least 10 meters
                ))
        .listen((Position position) {
      _updateLocation(position);
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _debounceTimer?.cancel(); // Dispose timer when not needed
    super.dispose();
  }

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
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              if (draggedPosition != null)
                MarkerLayer(markers: [
                  Marker(
                      point: draggedPosition!,
                      width: 80,
                      height: 80,
                      child: Icon(
                        Icons.location_on,
                        color: Colors.indigo,
                        size: 40,
                      )),
                ]),
              if (searchResultPosition !=
                  null) // Display blue marker from search
                MarkerLayer(markers: [
                  Marker(
                      point: searchResultPosition!,
                      width: 80,
                      height: 80,
                      child: Icon(
                        Icons.location_on,
                        color: Colors.blue, // Blue for search
                        size: 40,
                      )),
                ]),
              if (mylocation != null)
                MarkerLayer(markers: [
                  Marker(
                      point: mylocation!,
                      width: 80,
                      height: 80,
                      child: Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 40,
                      )),
                ]),
              CircleLayer(circles: dangerCircles),
              MarkerLayer(
                markers: markers,
              ),
              if (showDangerZone && accidentLocations.isNotEmpty)
                MarkerLayer(
                  markers: accidentLocations
                      .map((latlng) => Marker(
                          point: latlng,
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                          )))
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
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: isSearching
                              ? IconButton(
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() {
                                      isSearching = false;
                                      searchResults = [];
                                    });
                                  },
                                  icon: Icon(Icons.clear))
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
                              : Padding(
                                  padding: const EdgeInsets.all(8.0),
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
                    child: Icon(Icons.add_location),
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
                    child: Icon(Icons.wrong_location),
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
                    child: Icon(Icons.location_searching_outlined),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: FloatingActionButton(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      onPressed: () {
                        setState(() {
                          showDangerZone =
                              !showDangerZone; //Toggle danger zones
                          if (showDangerZone) {
                            _generateRandomAccidents(); // Add or refresh accidents
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
                      padding: EdgeInsets.only(top: 20),
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
                        child: Icon(Icons.location_searching_outlined),
                      ),
                    )
                ],
              ))
        ],
      ),
    );
  }
}
