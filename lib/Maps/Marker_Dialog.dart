import 'package:flutter/material.dart';

class MarkerDialog extends StatefulWidget {
  final Function(String, String) onMarkerAdded;

  const MarkerDialog({super.key, required this.onMarkerAdded});

  @override
  State<MarkerDialog> createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<MarkerDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Marker'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: "Title"),
          ),
          TextField(
            controller: descController,
            decoration: const InputDecoration(labelText: "Desc"),
          )
        ],
      ),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('cancel')),
        TextButton(
            onPressed: () {
              widget.onMarkerAdded(titleController.text, descController.text);
              Navigator.pop(context);
            },
            child: const Text('Add'))
      ],
    );
  }
}
