import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidmate_app/core/build_config.dart';
import 'package:vidmate_app/core/theme/theme_controller.dart';
import 'package:vidmate_app/database/hive_database.dart';
import 'package:vidmate_app/features/privacy/pin_screen.dart';
import 'package:vidmate_app/services/storage_service.dart';

/// Settings screen.
///
/// All options are now clickable and functional: appearance tiles toggle
/// selection, privacy options use real [Switch] widgets, and actionable
/// settings show a confirmation [SnackBar] when tapped. State is kept in a
/// [StatefulWidget] so changes reflect instantly on screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Appearance — backed by the global ThemeController so the whole app
  // actually switches theme instead of just highlighting a tile.
  ThemeMode get _themeMode => ThemeController.instance.mode.value;

  String get _themeLabel => switch (_themeMode) {
        ThemeMode.dark => 'Dark',
        ThemeMode.light => 'Light',
        ThemeMode.system => 'System',
      };

  static const String _themeKey = 'theme_mode';
  static const String _wifiOnlyKey = 'wifi_only';
  static const String _autoRetryKey = 'auto_retry';
  static const String _notificationsKey = 'notifications';
  static const String _autoplayKey = 'autoplay';
  static const String _backgroundAudioKey = 'background_audio';
  static const String _pipModeKey = 'pip_mode';
  static const String _vaultPinKey = 'vault_pin';
  static const String _fingerprintKey = 'fingerprint';
  static const String _clipboardDetectionKey = 'clipboard_detection';
  static const String _videoQualityKey = 'video_quality'; // BUG 15
  static const String _simultaneousDownloadsKey = 'simultaneous_downloads'; // BUG 15
  static const String _playbackSpeedKey = 'playback_speed'; // BUG 15

  late Future<void> _initSettingsBox;
  bool _wifiOnly = true;
  bool _autoRetry = true;
  bool _notifications = true;
  bool _autoplay = false;
  bool _backgroundAudio = true;
  bool _pipMode = true;
  bool _vaultPin = false;
  bool _fingerprint = false;
  bool _clipboardDetection = true;
  String _videoQuality = '720p'; // BUG 15: Default video quality
  int _simultaneousDownloads = 3; // BUG 15: Default simultaneous downloads
  double _playbackSpeed = 1.0; // BUG 15: Default playback speed

  String _usedStorage = 'Loading...';
  String _cacheSize = 'Loading...';
  String _historyCount = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initSettingsBox = _loadSettings();
    _loadStorageStats();
  }

  Future<void> _loadStorageStats() async {
    try {
      final stats = await StorageService.getStorageStats();
      if (!mounted) return;
      setState(() {
        _usedStorage = stats['used'] ?? 'N/A';
        _cacheSize = stats['cache'] ?? 'N/A';
        _historyCount = stats['downloads'] ?? '0 downloads';
      });
    } catch (e) {
      debugPrint('SETTINGS: Error loading storage stats - $e');
    }
  }

  Future<void> _loadSettings() async {
    debugPrint('SETTINGS: loading via getSettingsBox()');
    final settingsBox = await getSettingsBox();
    final themeMode = settingsBox.get(_themeKey) as String?;
    final wifiOnly = settingsBox.get(_wifiOnlyKey) as bool? ?? true;
    final autoRetry = settingsBox.get(_autoRetryKey) as bool? ?? true;
    final notifications = settingsBox.get(_notificationsKey) as bool? ?? true;
    final autoplay = settingsBox.get(_autoplayKey) as bool? ?? false;
    final backgroundAudio = settingsBox.get(_backgroundAudioKey) as bool? ?? true;
    final pipMode = settingsBox.get(_pipModeKey) as bool? ?? true;
    final vaultPin = settingsBox.get(_vaultPinKey) as bool? ?? false;
    final fingerprint = settingsBox.get(_fingerprintKey) as bool? ?? false;
    final clipboardDetection = settingsBox.get(_clipboardDetectionKey) as bool? ?? true;
    final videoQuality = settingsBox.get(_videoQualityKey) as String? ?? '720p'; // BUG 15
    final simultaneousDownloads = settingsBox.get(_simultaneousDownloadsKey) as int? ?? 3; // BUG 15
    final playbackSpeed = settingsBox.get(_playbackSpeedKey) as double? ?? 1.0; // BUG 15

    if (!mounted) return;
    setState(() {
      _wifiOnly = wifiOnly;
      _autoRetry = autoRetry;
      _notifications = notifications;
      _autoplay = autoplay;
      _backgroundAudio = backgroundAudio;
      _pipMode = pipMode;
      _vaultPin = vaultPin;
      _fingerprint = fingerprint;
      _clipboardDetection = clipboardDetection;
      _videoQuality = videoQuality; // BUG 15
      _simultaneousDownloads = simultaneousDownloads; // BUG 15
      _playbackSpeed = playbackSpeed; // BUG 15
      // Theme mode needs conversion from string to ThemeMode
      if (themeMode != null) {
        final mode = themeMode == 'dark' ? ThemeMode.dark
            : themeMode == 'light' ? ThemeMode.light
            : ThemeMode.system;
        ThemeController.instance.mode.value = mode;
      }
    });
  }

  void _saveSetting<T>(String key, T value) async {
    debugPrint('SETTINGS: saving $key via getSettingsBox()');
    final settingsBox = await getSettingsBox();
    // ignore: argument_type_not_assignable
    (settingsBox as dynamic).put(key, value);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF6C5Ce7)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder(future: _initSettingsBox, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint('SETTINGS: Error loading settings - ${snapshot.error}');
          return Center(child: Text('Error loading settings: ${snapshot.error}', style: TextStyle(color: Colors.red)));
        }
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Appearance section
                _buildSectionTitle(context, 'Appearance'),
                const SizedBox(height: 8),
                _buildAppearanceOptions(context),
                const SizedBox(height: 24),

                // Downloads section
                _buildSectionTitle(context, 'Downloads'),
                const SizedBox(height: 8),
                _buildDownloadSettings(context),
                const SizedBox(height: 24),

                // Storage section
                _buildSectionTitle(context, 'Storage'),
                const SizedBox(height: 8),
                _buildStorageOptions(context),
                const SizedBox(height: 24),

                // Player section
                _buildSectionTitle(context, 'Player'),
                const SizedBox(height: 8),
                _buildPlayerSettings(context),
                const SizedBox(height: 24),

                // Privacy section
                _buildSectionTitle(context, 'Privacy'),
                const SizedBox(height: 8),
                _buildPrivacySettings(context),
                const SizedBox(height: 24),

                // App Info section
                _buildSectionTitle(context, 'App Info'),
                const SizedBox(height: 8),
                _buildAppInfo(context),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.displaySmall,
    );
  }

  // ---- Appearance ----

  Widget _buildAppearanceOptions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildAppearanceTile(context, 'Dark', Icons.dark_mode, ThemeMode.dark),
              const SizedBox(width: 8),
              _buildAppearanceTile(context, 'Light', Icons.light_mode, ThemeMode.light),
              const SizedBox(width: 8),
              _buildAppearanceTile(context, 'System', Icons.autorenew, ThemeMode.system),
            ],
          ),
          const SizedBox(height: 8),
          // On-screen marker so the user can see the active theme actually
          // changed (CLAUDE.md: every fix needs a visible on-screen proof).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Active theme: $_themeLabel',
              style: const TextStyle(
                color: Color(0xFF6C5Ce7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceTile(
      BuildContext context, String label, IconData icon, ThemeMode value) {
    final isSelected = _themeMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ThemeController.instance.setMode(value);
          setState(() {}); // refresh the selection highlight + marker
          _snack('Theme set to $label');
        },
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C5Ce7) : const Color(0xFF2A2D3E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Downloads ----

  Widget _buildDownloadSettings(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            context, 'Video Quality', _videoQuality, Icons.videocam,
            onTap: () => _showVideoQualityPicker(context),
          ),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildSettingTile(
            context, 'Simultaneous Downloads', _simultaneousDownloads.toString(), Icons.download,
            onTap: () => _showSimDownloadsPicker(context),
          ),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildToggleTile(
            context, 'Wi-Fi Only', _wifiOnly,
            (v) {
              final val = v ?? false;
              setState(() => _wifiOnly = val);
              _saveSetting(_wifiOnlyKey, val);
              _snack('Wi-Fi Only: ${val ? 'Enabled' : 'Disabled'}');
            }, Icons.wifi,
          ),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildToggleTile(
            context, 'Auto-Retry', _autoRetry,
            (v) {
              final val = v ?? false;
              setState(() => _autoRetry = val);
              _saveSetting(_autoRetryKey, val);
              _snack('Auto-Retry: ${val ? 'Enabled' : 'Disabled'}');
            }, Icons.repeat,
          ),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildToggleTile(
            context, 'Notifications', _notifications,
            (v) {
              final val = v ?? false;
              setState(() => _notifications = val);
              _saveSetting(_notificationsKey, val);
              _snack('Notifications: ${val ? 'Enabled' : 'Disabled'}');
            }, Icons.notifications,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, String label, String value, IconData icon, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6C5Ce7)),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      onTap: onTap,
    );
  }

  Widget _buildToggleTile(
    BuildContext context, String label, bool value,
    ValueChanged<bool?> onChanged, IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6C5Ce7)),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Switch(
        value: value,
        onChanged: (v) {
          onChanged(v);
          _snack('$label: ${v ? 'Enabled' : 'Disabled'}'); // BUG 16: Toggle snack
        },
        activeThumbColor: const Color(0xFF6C5Ce7),
      ),
    );
  }

  // ---- Storage ----

  Widget _buildStorageOptions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildStorageInfoTile(context, 'Used', _usedStorage),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildStorageInfoTile(context, 'Cache', _cacheSize),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildStorageInfoTile(context, 'History', _historyCount),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildDeleteStorageButton(context),
        ],
      ),
    );
  }

  Widget _buildStorageInfoTile(BuildContext context, String label, String value) {
    return ListTile(
      leading: const Icon(Icons.storage, color: Color(0xFF6C5Ce7)),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }

  Widget _buildDeleteStorageButton(BuildContext context) {
    return TextButton(
      onPressed: () async {
        try {
          final tempDir = await getTemporaryDirectory();
          final cacheDir = await getApplicationCacheDirectory();
          int clearedBytes = 0;
          if (tempDir.existsSync()) {
            clearedBytes += _dirSize(tempDir);
            tempDir.deleteSync(recursive: true);
            tempDir.createSync(recursive: true);
          }
          if (cacheDir.existsSync()) {
            clearedBytes += _dirSize(cacheDir);
            cacheDir.deleteSync(recursive: true);
            cacheDir.createSync(recursive: true);
          }
          await _loadStorageStats();
          _snack('Freed up ${(clearedBytes / (1024 * 1024)).toStringAsFixed(1)} MB from cache & temp');
        } catch (e) {
          debugPrint('SETTINGS: Error clearing space - $e');
          _snack('Cache clear failed: $e');
        }
      },
      child: const Text(
        'Free up space',
        style: TextStyle(color: Color(0xFF6C5Ce7)),
      ),
    );
  }

  int _dirSize(Directory dir) {
    int sum = 0;
    try {
      for (var f in dir.listSync(recursive: true)) {
        if (f is File) sum += f.lengthSync();
      }
    } catch (_) {}
    return sum;
  }

  // ---- Player ----

  Widget _buildPlayerSettings(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            context, 'Playback Speed', '${_playbackSpeed}x', Icons.speed,
            onTap: () => _showPlaybackSpeedPicker(context),
          ),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildToggleTile(
            context, 'Autoplay', _autoplay,
            (v) {
              final val = v ?? false;
              setState(() => _autoplay = val);
              _saveSetting(_autoplayKey, val);
              _snack('Autoplay: ${val ? 'Enabled' : 'Disabled'}'); // BUG 16: Toggle snack
            }, Icons.autorenew,
          ),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildToggleTile(
            context, 'Background Audio', _backgroundAudio,
            (v) {
              final val = v ?? false;
              setState(() => _backgroundAudio = val);
              _saveSetting(_backgroundAudioKey, val);
              _snack('Background Audio: ${val ? 'Enabled' : 'Disabled'}'); // BUG 16: Toggle snack
            }, Icons.audiotrack,
          ),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildToggleTile(
            context, 'PiP Mode', _pipMode,
            (v) {
              final val = v ?? false;
              setState(() => _pipMode = val);
              _saveSetting(_pipModeKey, val);
              _snack('PiP Mode: ${val ? 'Enabled' : 'Disabled'}'); // BUG 16: Toggle snack
            }, Icons.picture_in_picture,
          ),
        ],
      ),
    );
  }

  // ---- Privacy ----

  Widget _buildPrivacySettings(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildToggleTile(
            context, 'Vault PIN', _vaultPin,
            (v) async {
              final val = v ?? false;
              setState(() => _vaultPin = val);
              _saveSetting(_vaultPinKey, val);
              _snack('Vault PIN: ${val ? 'Enabled' : 'Disabled'}'); // BUG 16: Toggle snack
              if (val) {
                _snack('Vault PIN enabled. Set your PIN to continue.');
                // Navigate to PIN setup screen
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PinScreen(isEntryMode: false),
                  ),
                );
                if (result == true) {
                  _snack('Vault PIN set successfully!');
                }
              }
            }, Icons.lock,
          ),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildToggleTile(
            context, 'Fingerprint', _fingerprint,
            (v) async {
              final val = v ?? false;
              setState(() => _fingerprint = val);
              _saveSetting(_fingerprintKey, val);
              _snack('Fingerprint: ${val ? 'Enabled' : 'Disabled'}'); // BUG 16: Toggle snack
              // BUG 10 proof: fingerprint toggle now integrates local_auth
              if (val && _vaultPin) {
                // Verify fingerprint works as biometric bypass for Vault PIN
                final authOk = await PinScreen.authWithFingerprint();
                if (authOk) {
                  _snack('Fingerprint auth success — Vault unlocked!');
                } else {
                  _snack('Fingerprint not available. PIN fallback will be used.');
                }
              }
            }, Icons.fingerprint,
          ),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildToggleTile(
            context, 'Clipboard Detection', _clipboardDetection,
            (v) {
              final val = v ?? false;
              setState(() => _clipboardDetection = val);
              _saveSetting(_clipboardDetectionKey, val);
              _snack('Clipboard Detection: ${val ? 'Enabled' : 'Disabled'}'); // BUG 16: Toggle snack
            }, Icons.copy,
          ),
          const Divider(color: Color(0xFF3A3D4F)),
          _buildSettingTile(
            context, 'Clear History', '', Icons.delete,
            onTap: () => _confirmClearHistory(context), // BUG 12: Clear History confirmation
          ),
        ],
      ),
    );
  }

  // BUG 12 Fix: Clear History confirmation dialog
  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3E),
        title: const Text('Clear History', style: TextStyle(color: Colors.white)),
        content: const Text('Kya aap apni poori search history delete karna chahte hain?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear', style: TextStyle(color: Color(0xFFFF7675))), // Red for destructive action
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final searchHistoryBox = await getSearchHistoryBox();
        await searchHistoryBox.clear();
        _snack('Search history cleared');
      } catch (e) {
        debugPrint('SETTINGS: Error clearing search history - $e');
        _snack('Search history clear nahi ho saki: $e');
      }
    }
  }

  // ---- App Info ----

  Widget _buildAppInfo(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Version ${BuildConfig.fullVersion}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }

  // BUG 15: Picker methods
  Future<void> _showVideoQualityPicker(BuildContext context) async {
    final qualities = ['360p', '720p', '1080p', '4K'];
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Quality', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2A2D3E),
        children: qualities.map((q) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, q),
          child: Text(q, style: const TextStyle(color: Colors.white)),
        )).toList(),
      ),
    );
    if (selected != null) {
      setState(() => _videoQuality = selected);
      _saveSetting(_videoQualityKey, selected);
      _snack('Quality set to $selected');
    }
  }

  Future<void> _showSimDownloadsPicker(BuildContext context) async {
    final values = [1, 2, 3, 4, 5];
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Max Downloads', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2A2D3E),
        children: values.map((v) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, v),
          child: Text(v.toString(), style: const TextStyle(color: Colors.white)),
        )).toList(),
      ),
    );
    if (selected != null) {
      setState(() => _simultaneousDownloads = selected);
      _saveSetting(_simultaneousDownloadsKey, selected);
      _snack('Max downloads: $selected');
    }
  }

  Future<void> _showPlaybackSpeedPicker(BuildContext context) async {
    final speeds = [0.5, 1.0, 1.5, 2.0];
    final selected = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Playback Speed', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2A2D3E),
        children: speeds.map((s) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, s),
          child: Text('${s}x', style: const TextStyle(color: Colors.white)),
        )).toList(),
      ),
    );
    if (selected != null) {
      setState(() => _playbackSpeed = selected);
      _saveSetting(_playbackSpeedKey, selected);
      _snack('Playback speed: ${selected}x');
    }
  }
}