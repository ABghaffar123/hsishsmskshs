/// Release notes for VidiMate app version history

class ReleaseNotes {
  /// Current version
  static const String currentVersion = '1.0.4';

  /// Release notes by version
  static Map<String, String> get notesByVersion => {
        '1.0.0': 'Initial release\n\n'
            '- VidiMate app launched\n'
            '- Home screen with paste link functionality\n'
            '- Discover screen with video browsing\n'
            '- Downloads management\n'
            '- Library with favorites and watch later\n'
            '- Settings with appearance and privacy options\n'
            '- Local database with Hive\n'
            '- Mock backend service\n'
            '- Dark mode UI\n'
            '- Bottom navigation\n'
            '- Skeleton shimmer loading',

        '1.0.1': 'Bug fixes and improvements\n\n'
            '- Fixed version number to 1.0.1+1\n'
            '- Improved theme consistency\n'
            '- Enhanced skeleton loading states\n'
            '- Fixed bottom navigation transitions\n'
            '- Improved mock data quality\n'
            '- Added API client for backend',

        '1.0.2': 'Security and performance improvements\n\n'
            '- Fixed security vulnerabilities\n'
            '- Improved download performance\n'
            '- Fixed crash on permission denial\n'
            '- Enhanced privacy protections',

        '1.0.3': 'New features and UI improvements\n\n'
            '- Added Private Vault feature\n'
            '- Improved dark mode styling\n'
            '- Enhanced bottom navigation\n'
            '- Added language selection (English/Urdu)\n'
            '- Fixed download folder selection',

        '1.0.4': 'Backend integration and bug fixes\n\n'
            '- Connected to FastAPI backend\n'
            '- Real video discover from Piped/Invidious\n'
            '- Real download functionality\n'
            '- Fixed player screen issues\n'
            '- Improved error handling'
      };

  /// Get notes for current version
  static String getCurrentNotes() {
    return notesByVersion[currentVersion] ?? 'No release notes available';
  }

  /// Check if this is a new major release
  static bool isMajorRelease(String version) {
    final parts = version.split('.');
    return parts.length >= 3 && parts[1] == '0' && parts[2] == '0';
  }
}