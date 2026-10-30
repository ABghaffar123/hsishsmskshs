import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive box names
class BoxNames {
  static const downloads = 'downloads';
  static const favorites = 'favorites';
  static const watchLater = 'watch_later';
  static const continueWatching = 'continue_watching';
  static const settings = 'settings';
  static const privateVault = 'private_vault';
  static const searchHistory = 'search_history';
}

/// Download model for Hive
class DownloadModel extends HiveObject {
  final String id;
  final String title;
  final String sourceUrl;
  final String thumbnail;
  final String quality;
  final String fileType;
  final String filePath;
  final double size;
  final String duration;
  final String status;
  final double progress;
  final double speed;
  final String eta;
  final Map<String, dynamic> dates;
  final String error;

  DownloadModel({
    required this.id,
    required this.title,
    required this.sourceUrl,
    required this.thumbnail,
    required this.quality,
    required this.fileType,
    required this.filePath,
    required this.size,
    required this.duration,
    required this.status,
    required this.progress,
    required this.speed,
    required this.eta,
    required this.dates,
    required this.error,
  });

  factory DownloadModel.fromMap(Map<String, dynamic> map) => DownloadModel(
        id: map['id'] as String,
        title: map['title'] as String,
        sourceUrl: map['sourceUrl'] as String,
        thumbnail: map['thumbnail'] as String,
        quality: map['quality'] as String,
        fileType: map['fileType'] as String,
        filePath: map['filePath'] as String,
        size: (map['size'] as num).toDouble(),
        duration: map['duration'] as String,
        status: map['status'] as String,
        progress: (map['progress'] as num).toDouble(),
        speed: (map['speed'] as num).toDouble(),
        eta: map['eta'] as String,
        dates: map['dates'] as Map<String, dynamic>,
        error: map['error'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'sourceUrl': sourceUrl,
        'thumbnail': thumbnail,
        'quality': quality,
        'fileType': fileType,
        'filePath': filePath,
        'size': size,
        'duration': duration,
        'status': status,
        'progress': progress,
        'speed': speed,
        'eta': eta,
        'dates': dates,
        'error': error,
      };
}

/// Favorites model for Hive
class FavoriteModel extends HiveObject {
  final String id;
  final String mediaId;
  final String title;
  final String thumbnail;
  final String fileType;
  final String filePath;
  final DateTime addedAt;

  FavoriteModel({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.thumbnail,
    required this.fileType,
    required this.filePath,
    required this.addedAt,
  });

  factory FavoriteModel.fromMap(Map<String, dynamic> map) => FavoriteModel(
        id: map['id'] as String,
        mediaId: map['mediaId'] as String,
        title: map['title'] as String,
        thumbnail: map['thumbnail'] as String,
        fileType: map['fileType'] as String,
        filePath: map['filePath'] as String,
        addedAt: DateTime.parse(map['addedAt'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'mediaId': mediaId,
        'title': title,
        'thumbnail': thumbnail,
        'fileType': fileType,
        'filePath': filePath,
        'addedAt': addedAt.toIso8601String(),
      };
}

/// Watch Later model for Hive
class WatchLaterModel extends HiveObject {
  final String id;
  final String sourceUrl;
  final String title;
  final String thumbnail;
  final String duration;
  final DateTime addedAt;
  final bool isDownloaded;

  WatchLaterModel({
    required this.id,
    required this.sourceUrl,
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.addedAt,
    required this.isDownloaded,
  });

  factory WatchLaterModel.fromMap(Map<String, dynamic> map) => WatchLaterModel(
        id: map['id'] as String,
        sourceUrl: map['sourceUrl'] as String,
        title: map['title'] as String,
        thumbnail: map['thumbnail'] as String,
        duration: map['duration'] as String,
        addedAt: DateTime.parse(map['addedAt'] as String),
        isDownloaded: map['isDownloaded'] as bool,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sourceUrl': sourceUrl,
        'title': title,
        'thumbnail': thumbnail,
        'duration': duration,
        'addedAt': addedAt.toIso8601String(),
        'isDownloaded': isDownloaded,
      };
}

/// Continue Watching model for Hive
class ContinueWatchingModel extends HiveObject {
  final String id;
  final String mediaId;
  final String title;
  final String thumbnail;
  final String filePath;
  final int watchedSeconds;
  final int totalDuration;
  final DateTime lastWatchedAt;

  ContinueWatchingModel({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.thumbnail,
    required this.filePath,
    required this.watchedSeconds,
    required this.totalDuration,
    required this.lastWatchedAt,
  });

  factory ContinueWatchingModel.fromMap(Map<String, dynamic> map) => ContinueWatchingModel(
        id: map['id'] as String,
        mediaId: map['mediaId'] as String,
        title: map['title'] as String,
        thumbnail: map['thumbnail'] as String,
        filePath: map['filePath'] as String,
        watchedSeconds: (map['watchedSeconds'] as num).toInt(),
        totalDuration: (map['totalDuration'] as num).toInt(),
        lastWatchedAt: DateTime.parse(map['lastWatchedAt'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'mediaId': mediaId,
        'title': title,
        'thumbnail': thumbnail,
        'filePath': filePath,
        'watchedSeconds': watchedSeconds,
        'totalDuration': totalDuration,
        'lastWatchedAt': lastWatchedAt.toIso8601String(),
      };
}

/// Settings model for Hive
class SettingsModel extends HiveObject {
  final bool theme;
  final String accent;
  final String language;
  final List<String> qualities;
  final String location;
  final bool wifiOnly;
  final bool autoRetry;
  final bool notifications;
  final int simultaneousDownloads;
  final String backendUrl;
  final String apiKey;

  SettingsModel({
    required this.theme,
    required this.accent,
    required this.language,
    required this.qualities,
    required this.location,
    required this.wifiOnly,
    required this.autoRetry,
    required this.notifications,
    required this.simultaneousDownloads,
    required this.backendUrl,
    required this.apiKey,
  });

  factory SettingsModel.fromMap(Map<String, dynamic> map) => SettingsModel(
        theme: map['theme'] as bool,
        accent: map['accent'] as String,
        language: map['language'] as String,
        qualities: List<String>.from(map['qualities']),
        location: map['location'] as String,
        wifiOnly: map['wifiOnly'] as bool,
        autoRetry: map['autoRetry'] as bool,
        notifications: map['notifications'] as bool,
        simultaneousDownloads: (map['simultaneousDownloads'] as num).toInt(),
        backendUrl: map['backendUrl'] as String,
        apiKey: map['apiKey'] as String,
      );

  Map<String, dynamic> toMap() => {
        'theme': theme,
        'accent': accent,
        'language': language,
        'qualities': qualities,
        'location': location,
        'wifiOnly': wifiOnly,
        'autoRetry': autoRetry,
        'notifications': notifications,
        'simultaneousDownloads': simultaneousDownloads,
        'backendUrl': backendUrl,
        'apiKey': apiKey,
      };
}

/// Private Vault model for Hive
class PrivateVaultModel extends HiveObject {
  final String id;
  final String mediaId;
  final String title;
  final String thumbnail;
  final String fileType;
  final String filePath;
  final DateTime movedAt;
  final bool isLocked;

  PrivateVaultModel({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.thumbnail,
    required this.fileType,
    required this.filePath,
    required this.movedAt,
    required this.isLocked,
  });

  factory PrivateVaultModel.fromMap(Map<String, dynamic> map) => PrivateVaultModel(
        id: map['id'] as String,
        mediaId: map['mediaId'] as String,
        title: map['title'] as String,
        thumbnail: map['thumbnail'] as String,
        fileType: map['fileType'] as String,
        filePath: map['filePath'] as String,
        movedAt: DateTime.parse(map['movedAt'] as String),
        isLocked: map['isLocked'] as bool,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'mediaId': mediaId,
        'title': title,
        'thumbnail': thumbnail,
        'fileType': fileType,
        'filePath': filePath,
        'movedAt': movedAt.toIso8601String(),
        'isLocked': isLocked,
      };
}

/// Search History model for Hive
class SearchHistoryModel extends HiveObject {
  final String id;
  final String query;
  final DateTime searchedAt;

  SearchHistoryModel({
    required this.id,
    required this.query,
    required this.searchedAt,
  });

  factory SearchHistoryModel.fromMap(Map<String, dynamic> map) => SearchHistoryModel(
        id: map['id'] as String,
        query: map['query'] as String,
        searchedAt: DateTime.parse(map['searchedAt'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'query': query,
        'searchedAt': searchedAt.toIso8601String(),
      };
}

/// Open a box safely, recovering from a corrupt box file by deleting and
/// recreating it. Without this, a single corrupt box hangs initHive()
/// forever (and every subsequent box open stays pending).
Future<void> _safeOpenBox<T>(String name) async {
  try {
    await Hive.openBox<T>(name);
  } catch (e) {
    debugPrint('HIVE: Box "$name" corrupt, recreating - $e');
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (deleteError) {
      debugPrint('HIVE: deleteBoxFromDisk failed for "$name" - $deleteError');
    }
    await Hive.openBox<T>(name);
  }
}

/// Initialize Hive database
Future<void> initHive() async {
  await Hive.initFlutter();

  // Register all adapters
  Hive.registerAdapter(DownloadAdapter());
  Hive.registerAdapter(FavoriteAdapter());
  Hive.registerAdapter(WatchLaterAdapter());
  Hive.registerAdapter(ContinueWatchingAdapter());
  Hive.registerAdapter(SettingsAdapter());
  Hive.registerAdapter(PrivateVaultAdapter());
  Hive.registerAdapter(SearchHistoryAdapter());

  // Open all boxes with corruption recovery so one bad box never blocks the
  // rest (and never hangs the app on startup).
  await _safeOpenBox<DownloadModel>(BoxNames.downloads);
  await _safeOpenBox<FavoriteModel>(BoxNames.favorites);
  await _safeOpenBox<WatchLaterModel>(BoxNames.watchLater);
  await _safeOpenBox<ContinueWatchingModel>(BoxNames.continueWatching);
  await _safeOpenBox<SettingsModel>(BoxNames.settings);
  await _safeOpenBox<PrivateVaultModel>(BoxNames.privateVault);
  await _safeOpenBox<SearchHistoryModel>(BoxNames.searchHistory);
}

/// Single safe accessor for the settings box.
///
/// Prevents "box already open" errors by checking [Hive.isBoxOpen] first.
/// Every caller in the app MUST use this instead of calling
/// `Hive.openBox('settings')` directly.
Future<Box<SettingsModel>> getSettingsBox() async {
  if (Hive.isBoxOpen(BoxNames.settings)) {
    return Hive.box<SettingsModel>(BoxNames.settings);
  }
  return Hive.openBox<SettingsModel>(BoxNames.settings);
}

Future<Box<SearchHistoryModel>> getSearchHistoryBox() async {
  if (Hive.isBoxOpen(BoxNames.searchHistory)) {
    return Hive.box<SearchHistoryModel>(BoxNames.searchHistory);
  }
  return Hive.openBox<SearchHistoryModel>(BoxNames.searchHistory);
}

Future<Box<DownloadModel>> getDownloadsBox() async {
  if (Hive.isBoxOpen(BoxNames.downloads)) {
    return Hive.box<DownloadModel>(BoxNames.downloads);
  }
  return Hive.openBox<DownloadModel>(BoxNames.downloads);
}

Future<Box<FavoriteModel>> getFavoritesBox() async {
  if (Hive.isBoxOpen(BoxNames.favorites)) {
    return Hive.box<FavoriteModel>(BoxNames.favorites);
  }
  return Hive.openBox<FavoriteModel>(BoxNames.favorites);
}

/// Download Adapter for Hive
class DownloadAdapter extends TypeAdapter<DownloadModel> {
  @override
  final int typeId = 1;

  @override
  DownloadModel read(BinaryReader reader) => DownloadModel.fromMap(
        Map<String, dynamic>.from(reader.readMap()),
      );

  @override
  void write(BinaryWriter writer, DownloadModel obj) {
    writer.writeMap(obj.toMap());
  }
}

/// Favorite Adapter for Hive
class FavoriteAdapter extends TypeAdapter<FavoriteModel> {
  @override
  final int typeId = 2;

  @override
  FavoriteModel read(BinaryReader reader) => FavoriteModel.fromMap(
        Map<String, dynamic>.from(reader.readMap()),
      );

  @override
  void write(BinaryWriter writer, FavoriteModel obj) {
    writer.writeMap(obj.toMap());
  }
}

/// Watch Later Adapter for Hive
class WatchLaterAdapter extends TypeAdapter<WatchLaterModel> {
  @override
  final int typeId = 3;

  @override
  WatchLaterModel read(BinaryReader reader) => WatchLaterModel.fromMap(
        Map<String, dynamic>.from(reader.readMap()),
      );

  @override
  void write(BinaryWriter writer, WatchLaterModel obj) {
    writer.writeMap(obj.toMap());
  }
}

/// Continue Watching Adapter for Hive
class ContinueWatchingAdapter extends TypeAdapter<ContinueWatchingModel> {
  @override
  final int typeId = 4;

  @override
  ContinueWatchingModel read(BinaryReader reader) => ContinueWatchingModel.fromMap(
        Map<String, dynamic>.from(reader.readMap()),
      );

  @override
  void write(BinaryWriter writer, ContinueWatchingModel obj) {
    writer.writeMap(obj.toMap());
  }
}

/// Settings Adapter for Hive
class SettingsAdapter extends TypeAdapter<SettingsModel> {
  @override
  final int typeId = 5;

  @override
  SettingsModel read(BinaryReader reader) => SettingsModel.fromMap(
        Map<String, dynamic>.from(reader.readMap()),
      );

  @override
  void write(BinaryWriter writer, SettingsModel obj) {
    writer.writeMap(obj.toMap());
  }
}

/// Private Vault Adapter for Hive
class PrivateVaultAdapter extends TypeAdapter<PrivateVaultModel> {
  @override
  final int typeId = 6;

  @override
  PrivateVaultModel read(BinaryReader reader) => PrivateVaultModel.fromMap(
        Map<String, dynamic>.from(reader.readMap()),
      );

  @override
  void write(BinaryWriter writer, PrivateVaultModel obj) {
    writer.writeMap(obj.toMap());
  }
}

/// Search History Adapter for Hive
class SearchHistoryAdapter extends TypeAdapter<SearchHistoryModel> {
  @override
  final int typeId = 7;

  @override
  SearchHistoryModel read(BinaryReader reader) => SearchHistoryModel.fromMap(
        Map<String, dynamic>.from(reader.readMap()),
      );

  @override
  void write(BinaryWriter writer, SearchHistoryModel obj) {
    writer.writeMap(obj.toMap());
  }
}
