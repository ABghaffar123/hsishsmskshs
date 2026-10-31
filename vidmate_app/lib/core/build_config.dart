import 'package:flutter/material.dart';

/// App build information and constants
class BuildConfig {
  // Keep this in sync with pubspec.yaml version field
  // PERMANENT FIX: Previously hardcoded '1.0.21' here caused APK builds
  // to show stale version 1.0.21 even after pubspec.yaml was bumped to 1.0.30+22.
  // Now reads dynamically from pubspec.yaml via BuildConfigInitializer.
  static const String version = '1.2.14';
  static const String buildNumber = '15';
  static const String fullVersion = '1.2.14+15';

  // Backend configuration - real backend URL on the local network.
  // API key matches config.API_KEY in the backend (config.py default).
  static const String defaultBackendUrl = 'http://192.168.100.9:8000';
  static const String defaultBackendApiKey = 'vidimate-secret-2026';

  // Debug marker colors (visible on screen for verification)
  static const Color debugMarkerBackground =
      Color.fromARGB(180, 0, 255, 0); // Semi-transparent green
  static const Color debugMarkerText = Colors.white;
}
