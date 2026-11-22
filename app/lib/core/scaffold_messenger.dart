import 'package:flutter/material.dart';

/// Global ScaffoldMessenger key allowing safe SnackBar presentations from anywhere
/// in the app, including models during defensive JSON parsing.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showParseErrorSnackBar(String raw) {
  rootScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text('Failed to parse date: $raw'),
      backgroundColor: Colors.red.shade700,
    ),
  );
}
