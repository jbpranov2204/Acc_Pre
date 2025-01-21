import 'package:flutter/material.dart';

class SavedLocationsDialog extends StatelessWidget {
  final List<Map<String, dynamic>> savedLocations;

  const SavedLocationsDialog({super.key, required this.savedLocations});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Saved Locations'),
      content: SizedBox(
        width: double.maxFinite,
        child: savedLocations.isEmpty
            ? const Text('No saved locations yet.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: savedLocations.length,
                itemBuilder: (context, index) {
                  final location = savedLocations[index];
                  return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(location['place_name'] ?? 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 8),
                            Text(
                                'Lat: ${location['latitude'].toStringAsFixed(4)}, Lng: ${location['longitude'].toStringAsFixed(4)}'),
                            const SizedBox(height: 8),
                            const Text(
                              'Surrounding locations:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ...(location['surrounding_locations'] as List).map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(left: 12.0),
                                child: Text(
                                  'Lat: ${e['latitude'].toStringAsFixed(4)}, Lng: ${e['longitude'].toStringAsFixed(4)}',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ));
                }),
      ),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'))
      ],
    );
  }
}
