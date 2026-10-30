import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Represents a folder containing media files
class MediaFolder {
  final String id;        // stable folder path (unique identity)
  final String name;       // display name
  final String path;
  final int videoCount;
  final Uint8List? previewThumbnail;

  MediaFolder({
    required this.id,
    required this.name,
    required this.path,
    required this.videoCount,
    this.previewThumbnail,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'path': path,
        'videoCount': videoCount,
      };

  factory MediaFolder.fromMap(Map<String, dynamic> map) => MediaFolder(
        id: map['id'],
        name: map['name'],
        path: map['path'],
        videoCount: map['videoCount'],
      );
}

/// Represents a local media file
class LocalMediaFile {
  final String id;
  final String title;
  final String path;
  final String folderPath;
  final int size;
  final DateTime modifiedAt;
  final int duration; // seconds, 0 if unknown
  final bool isVideo;

  LocalMediaFile({
    required this.id,
    required this.title,
    required this.path,
    required this.folderPath,
    required this.size,
    required this.modifiedAt,
    this.duration = 0,
    required this.isVideo,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'path': path,
        'folderPath': folderPath,
        'size': size,
        'modifiedAt': modifiedAt.toIso8601String(),
        'duration': duration,
        'isVideo': isVideo,
      };

  factory LocalMediaFile.fromMap(Map<String, dynamic> map) => LocalMediaFile(
        id: map['id'],
        title: map['title'],
        path: map['path'],
        folderPath: map['folderPath'],
        size: map['size'],
        modifiedAt: DateTime.parse(map['modifiedAt']),
        duration: map['duration'],
        isVideo: map['isVideo'],
      );
}

/// Scans the phone's external storage for real video files and returns them.
class LibraryVideoService {
  static const List<String> _videoExtensions = [
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts',
    '.3gp', '.3g2',
  ];

  static const List<String> _audioExtensions = [
    '.mp3', '.m4a', '.wav', '.flac', '.ogg', '.aac', '.wma', '.opus',
  ];

  static Box? _videosBox;
  static Box? _audioBox;
  static DateTime _lastScanTime = DateTime(0);
  static const _cacheDuration = Duration(minutes: 30);

  static Future<void> _ensureHive() async {
    if (_videosBox == null || !_videosBox!.isOpen) {
      if (!Hive.isBoxOpen('library_videos')) {
        _videosBox = await Hive.openBox('library_videos');
      } else {
        _videosBox = Hive.box('library_videos');
      }
    }
    if (_audioBox == null || !_audioBox!.isOpen) {
      if (!Hive.isBoxOpen('library_audio')) {
        _audioBox = await Hive.openBox('library_audio');
      } else {
        _audioBox = Hive.box('library_audio');
      }
    }
  }

  /// Requests storage permission. Returns true if granted.
  static Future<bool> requestStoragePermission() async {
    debugPrint('LIBRARY: requesting storage permission');
    final status = await Permission.storage.request();
    debugPrint('LIBRARY: storage permission status=$status');
    if (!status.isGranted) {
      final mediaStatus = await Permission.videos.request();
      debugPrint('LIBRARY: videos permission status=$mediaStatus');
      return mediaStatus.isGranted;
    }
    return status.isGranted;
  }

  /// Request audio permission separately
  static Future<bool> requestAudioPermission() async {
    final status = await Permission.audio.request();
    debugPrint('LIBRARY: audio permission status=$status');
    return status.isGranted;
  }

  /// Returns true if storage permission is available
  static Future<bool> hasStoragePermission() async {
    var status = await Permission.storage.status;
    if (status.isGranted) return true;
    status = await Permission.videos.status;
    return status.isGranted;
  }

  /// Returns true if audio permission is available
  static Future<bool> hasAudioPermission() async {
    return await Permission.audio.status.isGranted;
  }

  /// Clears the Hive cache so next scan fetches fresh data.
  static Future<void> clearCache() async {
    await _videosBox?.clear();
    await _audioBox?.clear();
    _lastScanTime = DateTime(0);
  }

  /// Adds a downloaded media file to MediaStore so it appears in the system
  /// Gallery/Files app. This makes downloads publicly visible.
  /// FIX: Previously downloaded media was only stored in Hive database but
  /// not registered with Android's MediaStore, making it invisible to the
  /// system Gallery and Files apps. Now we explicitly add entries.
  static Future<bool> addToMediaStore(String filePath, {bool isVideo = true}) async {
    if (!Platform.isAndroid) return true; // No-op on non-Android
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('MEDIA_STORE: file does not exist at $filePath');
        return false;
      }
      final size = await file.length();
      if (size <= 0) {
        debugPrint('MEDIA_STORE: file is empty at $filePath');
        return false;
      }

      const platform = MethodChannel('com.vidmate.app/media_store');
      final result = await platform.invokeMethod<bool>('addToMediaStore', {
        'path': filePath,
        'mimeType': isVideo ? 'video/mp4' : 'audio/mpeg',
        'isVideo': isVideo,
      });
      debugPrint('MEDIA_STORE: addToMediaStore result=$result for $filePath');
      return result ?? false;
    } catch (e) {
      debugPrint('MEDIA_STORE: addToMediaStore error - $e');
      return false;
    }
  }

  /// Scans a specific folder for recently added media files and indexes them
  /// in Hive. Used to ensure newly downloaded files appear in the Library.
  static Future<List<LocalMediaFile>?> scanSpecificFolder(
    String folderPath, {
    bool isVideo = true,
    bool forceRefresh = false,
  }) async {
    await _ensureHive();

    final granted = await hasStoragePermission();
    if (!granted) {
      debugPrint('LIBRARY: storage permission denied for folder scan');
      return null;
    }

    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      debugPrint('LIBRARY: folder does not exist -> $folderPath');
      return [];
    }

    final List<LocalMediaFile> found = [];
    await _scanDirectory(dir, found, isVideo: isVideo);

    debugPrint('LIBRARY: found ${found.length} file(s) in $folderPath');
    return found;
  }

  /// Indexes a list of local media files into the Hive cache,
  /// avoiding duplicates based on file path.
  static Future<void> indexMediaFiles(List<LocalMediaFile> files, {bool isVideo = true}) async {
    await _ensureHive();
    final box = isVideo ? _videosBox : _audioBox;
    if (box == null) return;

    for (final file in files) {
      final existing = _findByKey(box, file.path);
      if (existing == null) {
        await box.add(file.toMap());
        debugPrint('LIBRARY: indexed new file ${file.path}');
      }
    }
  }

  /// Finds a media file in Hive box by its path key (avoiding duplicates)
  static LocalMediaFile? _findByKey(Box box, String path) {
    for (var i = 0; i < box.length; i++) {
      final map = Map<String, dynamic>.from(box.getAt(i) as Map);
      if (map['path'] == path) {
        return LocalMediaFile.fromMap(map);
      }
    }
    return null;
  }

  /// Returns the list of real video files, or null when permission denied.
  /// Uses Hive for persistent caching across app restarts.
  static Future<List<LocalMediaFile>?> scanPhoneVideos({bool forceRefresh = false}) async {
    await _ensureHive();

    if (!forceRefresh && _videosBox != null && _videosBox!.isNotEmpty) {
      final cached = _videosBox!.values
          .map((v) => LocalMediaFile.fromMap(Map<String, dynamic>.from(v)))
          .toList();
      debugPrint('LIBRARY: returning Hive-cached videos (count=${cached.length})');
      return cached;
    }

    final granted = await hasStoragePermission();
    if (!granted) {
      debugPrint('LIBRARY: storage permission denied -> null');
      return null;
    }

    final List<LocalMediaFile> videos = [];
    final dirs = await _candidateDirectories();

    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      await _scanDirectory(dir, videos, isVideo: true);
    }

    videos.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    debugPrint('LIBRARY: found ${videos.length} real video file(s)');

    await _videosBox?.clear();
    for (final v in videos) {
      await _videosBox?.add(v.toMap());
    }

    return videos;
  }

  /// Scan for audio files with Hive persistence
  static Future<List<LocalMediaFile>?> scanPhoneAudio({bool forceRefresh = false}) async {
    await _ensureHive();

    if (!forceRefresh && _audioBox != null && _audioBox!.isNotEmpty) {
      final cached = _audioBox!.values
          .map((v) => LocalMediaFile.fromMap(Map<String, dynamic>.from(v)))
          .toList();
      debugPrint('LIBRARY: returning Hive-cached audio (count=${cached.length})');
      return cached;
    }

    final audioGranted = await hasAudioPermission();
    if (!audioGranted) {
      final granted = await requestAudioPermission();
      if (!granted) return null;
    }

    final List<LocalMediaFile> audioFiles = [];
    final dirs = await _candidateDirectories();

    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      await _scanDirectory(dir, audioFiles, isVideo: false);
    }

    audioFiles.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    debugPrint('LIBRARY: found ${audioFiles.length} real audio file(s)');

    await _audioBox?.clear();
    for (final a in audioFiles) {
      await _audioBox?.add(a.toMap());
    }

    return audioFiles;
  }

  /// Returns list of folders containing videos (folder-first browsing)
  static Future<List<MediaFolder>?> scanVideoFolders({bool forceRefresh = false}) async {
    final videos = await scanPhoneVideos(forceRefresh: forceRefresh);
    if (videos == null) return null;

    final Map<String, List<LocalMediaFile>> folderMap = {};
    for (final video in videos) {
      final folderPath = video.folderPath;
      if (!folderMap.containsKey(folderPath)) {
        folderMap[folderPath] = [];
      }
      folderMap[folderPath]!.add(video);
    }

    final List<MediaFolder> folders = [];
    for (final entry in folderMap.entries) {
      final path = entry.key;
      final files = entry.value;
      final name = path.split(Platform.pathSeparator).last;

      folders.add(MediaFolder(
        id: path,
        name: name.isEmpty ? 'Storage Root' : name,
        path: path,
        videoCount: files.length,
      ));
    }

    folders.sort((a, b) => b.videoCount.compareTo(a.videoCount));
    debugPrint('LIBRARY: found ${folders.length} video folders');
    return folders;
  }

  /// Candidate directories where phone videos normally live.
  static Future<List<Directory>> _candidateDirectories() async {
    final List<Directory> dirs = [];

    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final root = ext.parent.parent.parent.parent;
        dirs.add(Directory(root.path));
        dirs.add(Directory('${root.path}/Movies'));
        dirs.add(Directory('${root.path}/Download'));
        dirs.add(Directory('${root.path}/DCIM'));
        dirs.add(Directory('${root.path}/Documents'));
        dirs.add(Directory('${root.path}/Music'));
        dirs.add(Directory('${root.path}/Audio'));
      }
    } else {
      // Windows/macOS fallback for local testing
      final docs = await getApplicationDocumentsDirectory();
      dirs.add(docs);
    }

    // App documents directory as a fallback
    if (!Platform.isAndroid) {
      final fallbackDocs = await getApplicationDocumentsDirectory();
      dirs.add(fallbackDocs);
    }

    return dirs;
  }

  /// Recursively scans a directory for media files (bounded depth).
  static Future<void> _scanDirectory(
    Directory dir,
    List<LocalMediaFile> sink, {
    required bool isVideo,
    int depth = 0,
    int maxDepth = 4,
  }) async {
    if (depth > maxDepth) return;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (name == 'Android' || name == 'cache' || name == '.thumbnails' || name.startsWith('.')) {
            continue;
          }
          await _scanDirectory(entity, sink, isVideo: isVideo, depth: depth + 1, maxDepth: maxDepth);
          if (sink.length > 500) return;
        } else if (entity is File) {
          final lower = entity.path.toLowerCase();
          final extensions = isVideo ? _videoExtensions : _audioExtensions;
          if (extensions.any((ext) => lower.endsWith(ext))) {
            final parts = entity.path.split(Platform.pathSeparator);
            final fileName = parts.last;
            final fileSize = await entity.length();
            final modTime = await entity.lastModified();
            final folderPath = parts.sublist(0, parts.length - 1).join(Platform.pathSeparator);

            sink.add(LocalMediaFile(
              id: entity.path,
              title: fileName,
              path: entity.path,
              folderPath: folderPath,
              size: fileSize,
              modifiedAt: modTime,
              isVideo: isVideo,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('LIBRARY: scan error in ${dir.path} -> $e');
    }
  }

  /// Generate thumbnail for a local video file
  static Future<Uint8List?> generateVideoThumbnail(String filePath) async {
    try {
      const platform = MethodChannel('com.vidmate.app/thumbnails');
      try {
        final result = await platform.invokeMethod<Uint8List>('getThumbnail', {'path': filePath});
        if (result != null && result.length > 100) {
          return result;
        }
      } catch (e) {
        debugPrint('LIBRARY: platform thumbnail channel failed: $e');
      }
      return null;
    } catch (e) {
      debugPrint('LIBRARY: thumbnail generation error for $filePath: $e');
      return null;
    }
  }
}