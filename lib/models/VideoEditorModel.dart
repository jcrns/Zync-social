import 'package:flutter/material.dart';

// Represents a single text overlay on the video
class TextOverlay {
  String id;
  String text;
  Offset position; // Position relative to the video container (0.0 to 1.0)
  double scale;
  double rotation;
  TextStyle style;
  int startTimeMs;
  int endTimeMs;

  TextOverlay({
    required this.text,
    this.position = const Offset(0.5, 0.5), // Default to center
    this.scale = 1.0,
    this.rotation = 0.0,
    this.style = const TextStyle(color: Colors.white, fontSize: 24, shadows: [
      Shadow(blurRadius: 6.0, color: Colors.black54)
    ]),
    this.startTimeMs = 0,
    this.endTimeMs = 5000, // Default duration
  }) : id = UniqueKey().toString();
}

// Represents the state of the video trim
class TrimData {
  final int maxDurationMs;
  int startValueMs;
  int endValueMs;

  TrimData({
    required this.maxDurationMs,
    required this.startValueMs,
    required this.endValueMs,
  });
}

// Stores normalized crop rectangle (values between 0 and 1 relative to video display)
class CropData {
  // normalized left, top, right, bottom (0..1)
  final double left;
  final double top;
  final double right;
  final double bottom;

  CropData({required this.left, required this.top, required this.right, required this.bottom});

  Rect toRect(Size size) {
    return Rect.fromLTRB(left * size.width, top * size.height, right * size.width, bottom * size.height);
  }
}