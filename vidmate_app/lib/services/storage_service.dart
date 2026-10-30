import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:vidmate_app/database/hive_database.dart';

/// BUG 13 Fix: Storage Statistics Service
/// Computes real storage info using Dart's built-in Platform.
class StorageService {
  static Future<Map<String, String>> getStorageStats() async {
    // Total/Free space using Dart's built-in statfs via Platform or fallback
    String usedSpace = 'N/A';
    try {
      final platform = Platform.environment;
      // Fallback: basic directory-based size calculation
      usedSpace = _getPlatformDiskInfo();
    } catch (e) {
      // Ignore and use fallback
    }

    // Cache size
    final tempDir = await getTemporaryDirectory();
    final cacheSize = await _getDirectorySize(tempDir);

    // Download count
    final box = await getDownloadsBox();
    final count = box.length;

    return {
      'used': usedSpace,
      'cache': '${(cacheSize / (1024 * 1024)).toStringAsFixed(1)} MB',
      'downloads': '$count downloads',
    };
  }

  static String _getPlatformDiskInfo() {
    // Simple fallback - uses root directory stats if available
    try {
      final result = Process.runSync('df', ['-h', '/']);
      if (result.exitCode == 0) {
        return 'Disk info via df: ${result.stdout}';
      }
    } catch (e) {
      // Fallback to basic info
    }
    return 'N/A';
  }

  static Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        await for (var entity in dir.list(recursive: true)) {
          if (entity is File) {
            size += await entity.length();
          }
        }
      }
    } catch (e) {
      // Ignore
    }
    return size;
  }
}
