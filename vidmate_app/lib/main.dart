import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/build_config.dart';
import 'features/main/presentation/main_screen.dart';
import 'database/hive_database.dart';
import 'services/backend_api_client.dart';
import 'services/notification_service.dart';
import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom Error Widget to prevent black screen on UI crash
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'UI Error: ${details.exception}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  // Initialize Hive and register adapters
  try {
    await initHive();
    debugPrint('MAIN: Hive initialized');
  } catch (e) {
    debugPrint('MAIN: Hive init error - $e');
  }

  // BUG 7 Fix: Initialize background audio
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.vidimate.app.audio',
      androidNotificationChannelName: 'VidiMate Background Audio',
      androidNotificationOngoing: true,
    );
    debugPrint('MAIN: JustAudioBackground initialized (BUG 7 fix)');
  } catch (e) {
    debugPrint('MAIN: JustAudioBackground init error - $e');
  }

  // BUG 5 Fix: Initialize notification channels + request permission
  // before runApp so download-complete/failed notifications work.
  try {
    await NotificationService.initialize();
    debugPrint('MAIN: NotificationService initialized (BUG 5 fix)');
  } catch (e) {
    debugPrint('MAIN: NotificationService init error - $e');
  }

  // Initialize backend API client — real backend on LAN + shared API key
  BackendApiClient.initialize(
    baseUrl: BuildConfig.defaultBackendUrl,
    apiKey: BuildConfig.defaultBackendApiKey,
  );

  // Do NOT await verifyBackendConnectivity() here — it does network I/O that
  // can cause a black screen on app start. Instead, probe connectivity after
  // the first frame so the app becomes usable immediately. The offline/online
  // banner will update once the check completes.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    BackendApiClient.verifyBackendConnectivity();
  });

  runApp(const VidiMateApp());
}

class VidiMateApp extends StatefulWidget {
  const VidiMateApp({super.key});

  @override
  State<VidiMateApp> createState() => _VidiMateAppState();
}

class _VidiMateAppState extends State<VidiMateApp> {
  @override
  void initState() {
    super.initState();
    // Load persisted theme preference AFTER the first frame so the app
    // renders immediately instead of blocking on a Hive read. Errors are
    // caught and fall back to the system theme — never a black screen.
    ThemeController.instance.mode.addListener(_onThemeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ThemeController.instance.loadTheme().catchError((e) {
        debugPrint('THEME: loadTheme failed - $e');
      });
    });
  }

  @override
  void dispose() {
    ThemeController.instance.mode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidiMate',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Driven by the ThemeController so Dark/Light/System selection in
      // Settings actually switches the app theme.
      themeMode: ThemeController.instance.mode.value,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
  }
}
