import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vidmate_app/database/hive_database.dart';

/// Holds the active [ThemeMode] for the whole app.
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  static const String _themeKey = 'theme_mode';

  /// Return the settings box via the central safe accessor.
  ///
  /// Uses [getSettingsBox] which checks [Hive.isBoxOpen] first,
  /// preventing duplicate-open and type-mismatch errors.
  Future<Box> _ensureBox() async {
    return getSettingsBox();
  }

  /// Load persisted theme from Hive, falling back to system preference.
  Future<void> loadTheme() async {
    try {
      final box = await _ensureBox();
      final saved = box.get(_themeKey) as String?;
      if (saved != null) {
        mode.value = ThemeMode.values.firstWhere(
          (m) => m.toString().split('.').last == saved,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      debugPrint('THEME: Load theme error - $e');
      mode.value = ThemeMode.system;
    }
  }

  void setMode(ThemeMode m) async {
    final box = await _ensureBox();
    await box.put(_themeKey, m.toString().split('.').last);
    mode.value = m;
  }

  void setDark() => setMode(ThemeMode.dark);
  void setLight() => setMode(ThemeMode.light);
  void setSystem() => setMode(ThemeMode.system);
}