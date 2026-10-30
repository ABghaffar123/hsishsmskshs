import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vidmate_app/database/hive_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Box Fix Verification', () {
    setUp(() async {
      await Hive.initFlutter();
      // Simulate app startup which opens the box typed
      Hive.registerAdapter(SettingsAdapter());
      await Hive.openBox<SettingsModel>(BoxNames.settings);
    });

    tearDown(() async {
      await Hive.close();
    });

    test('getSettingsBox returns existing box when already open (no crash)', () async {
      // Must not throw HiveError: The box "settings" is already open
      final box = await getSettingsBox();
      expect(box.isOpen, isTrue);
      expect(box.name, equals('settings'));
    });

    test('multiple getSettingsBox calls return same instance without error', () async {
      final box1 = await getSettingsBox();
      final box2 = await getSettingsBox();
      expect(identical(box1, box2), isTrue);
    });
  });
}
