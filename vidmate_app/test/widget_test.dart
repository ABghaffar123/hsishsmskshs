import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:vidmate_app/main.dart';

void main() {
  testWidgets('VidiMate app loads without crashing', (WidgetTester tester) async {
    // Initialize Hive so ThemeController.loadTheme(), HomeScreen and
    // SettingsScreen can open/read their boxes during the test. The real
    // app calls initHive() from main(); the widget test bypasses main(),
    // so we replicate the minimal box openings here.
    await Hive.initFlutter();
    await Hive.openBox('settings');
    await Hive.openBox('downloads');

    // Build our app and trigger a frame.
    await tester.pumpWidget(const VidiMateApp());

    // Verify that the app loads without crashing.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Pump a couple of frames to let the theme controller settle its async
    // box read. Do NOT pumpAndSettle — the home screen's clipboard check and
    // backend connectivity probe are long-lived async operations that would
    // make the test hang indefinitely.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    await Hive.close();
  });
}