import 'package:hive_flutter/hive_flutter.dart';
import 'hive_database.dart';

/// Download repository for managing downloads
abstract class DownloadRepository {
  Future<void> add(DownloadModel download);
  Future<void> updateProgress(String id, double progress);
  Future<void> pause(String id);
  Future<void> resume(String id);
  Future<void> cancel(String id);
  Future<void> retry(String id);
  Future<List<DownloadModel>> filter({String? status});
  Future<void> delete(String id);
  Future<void> clearCompleted();
}

class HiveDownloadRepository implements DownloadRepository {
  final Box<DownloadModel> box;

  HiveDownloadRepository(this.box);

  @override
  Future<void> add(DownloadModel download) async {
    await box.put(download.id, download);
  }

  @override
  Future<void> updateProgress(String id, double progress) async {
    final download = box.get(id);
    if (download != null) {
      await box.put(
        id,
        DownloadModel(
          id: download.id,
          title: download.title,
          sourceUrl: download.sourceUrl,
          thumbnail: download.thumbnail,
          quality: download.quality,
          fileType: download.fileType,
          filePath: download.filePath,
          size: download.size,
          duration: download.duration,
          status: 'downloading',
          progress: progress,
          speed: download.speed,
          eta: download.eta,
          dates: {...download.dates, 'updatedAt': DateTime.now().toIso8601String()},
          error: download.error,
        ),
      );
    }
  }

  @override
  Future<void> pause(String id) async {
    final download = box.get(id);
    if (download != null) {
      await box.put(
        id,
        DownloadModel(
          id: download.id,
          title: download.title,
          sourceUrl: download.sourceUrl,
          thumbnail: download.thumbnail,
          quality: download.quality,
          fileType: download.fileType,
          filePath: download.filePath,
          size: download.size,
          duration: download.duration,
          status: 'paused',
          progress: download.progress,
          speed: download.speed,
          eta: download.eta,
          dates: download.dates,
          error: download.error,
        ),
      );
    }
  }

  @override
  Future<void> resume(String id) async {
    final download = box.get(id);
    if (download != null) {
      await box.put(
        id,
        DownloadModel(
          id: download.id,
          title: download.title,
          sourceUrl: download.sourceUrl,
          thumbnail: download.thumbnail,
          quality: download.quality,
          fileType: download.fileType,
          filePath: download.filePath,
          size: download.size,
          duration: download.duration,
          status: 'downloading',
          progress: download.progress,
          speed: download.speed,
          eta: download.eta,
          dates: download.dates,
          error: download.error,
        ),
      );
    }
  }

  @override
  Future<void> cancel(String id) async {
    final download = box.get(id);
    if (download != null) {
      await box.put(
        id,
        DownloadModel(
          id: download.id,
          title: download.title,
          sourceUrl: download.sourceUrl,
          thumbnail: download.thumbnail,
          quality: download.quality,
          fileType: download.fileType,
          filePath: download.filePath,
          size: download.size,
          duration: download.duration,
          status: 'cancelled',
          progress: download.progress,
          speed: download.speed,
          eta: download.eta,
          dates: download.dates,
          error: download.error,
        ),
      );
    }
  }

  @override
  Future<void> retry(String id) async {
    final download = box.get(id);
    if (download != null) {
      await box.put(
        id,
        DownloadModel(
          id: download.id,
          title: download.title,
          sourceUrl: download.sourceUrl,
          thumbnail: download.thumbnail,
          quality: download.quality,
          fileType: download.fileType,
          filePath: download.filePath,
          size: download.size,
          duration: download.duration,
          status: 'downloading',
          progress: 0,
          speed: download.speed,
          eta: download.eta,
          dates: download.dates,
          error: '',
        ),
      );
    }
  }

  @override
  Future<List<DownloadModel>> filter({String? status}) async {
    final all = box.values.toList();
    if (status == null) return all;
    return all.where((d) => d.status == status).toList();
  }

  @override
  Future<void> delete(String id) async {
    await box.delete(id);
  }

  @override
  Future<void> clearCompleted() async {
    final completed = box.values.where((d) => d.status == 'completed');
    for (final download in completed) {
      await box.delete(download.id);
    }
  }
}

/// Library repository for managing saved media
abstract class LibraryRepository {
  Future<List<FavoriteModel>> getFavorites();
  Future<void> addFavorite(FavoriteModel favorite);
  Future<void> removeFavorite(String id);

  Future<List<WatchLaterModel>> getWatchLater();
  Future<void> addToWatchLater(WatchLaterModel item);
  Future<void> removeFromWatchLater(String id);

  Future<List<PrivateVaultModel>> getPrivateVault();
  Future<void> addToVault(PrivateVaultModel item);
  Future<void> removeFromVault(String id);
}

class HiveLibraryRepository implements LibraryRepository {
  final Box<FavoriteModel> favoritesBox;
  final Box<WatchLaterModel> watchLaterBox;
  final Box<PrivateVaultModel> vaultBox;

  HiveLibraryRepository(this.favoritesBox, this.watchLaterBox, this.vaultBox);

  @override
  Future<List<FavoriteModel>> getFavorites() async {
    return favoritesBox.values.toList();
  }

  @override
  Future<void> addFavorite(FavoriteModel favorite) async {
    await favoritesBox.put(favorite.id, favorite);
  }

  @override
  Future<void> removeFavorite(String id) async {
    await favoritesBox.delete(id);
  }

  @override
  Future<List<WatchLaterModel>> getWatchLater() async {
    return watchLaterBox.values.toList();
  }

  @override
  Future<void> addToWatchLater(WatchLaterModel item) async {
    await watchLaterBox.put(item.id, item);
  }

  @override
  Future<void> removeFromWatchLater(String id) async {
    await watchLaterBox.delete(id);
  }

  @override
  Future<List<PrivateVaultModel>> getPrivateVault() async {
    return vaultBox.values.toList();
  }

  @override
  Future<void> addToVault(PrivateVaultModel item) async {
    await vaultBox.put(item.id, item);
  }

  @override
  Future<void> removeFromVault(String id) async {
    await vaultBox.delete(id);
  }
}

/// Settings repository for managing app settings
abstract class SettingsRepository {
  Future<SettingsModel> getSettings();
  Future<void> updateSettings(SettingsModel settings);
}

class HiveSettingsRepository implements SettingsRepository {
  final Box<SettingsModel> settingsBox;

  HiveSettingsRepository(this.settingsBox);

  @override
  Future<SettingsModel> getSettings() async {
    var settings = settingsBox.get('app_settings');
    if (settings == null) {
      settings = SettingsModel(
        theme: true,
        accent: '#6C5CE7',
        language: 'en',
        qualities: ['360p', '720p', '1080p', '4K'],
        location: '/VidiMate/',
        wifiOnly: false,
        autoRetry: true,
        notifications: true,
        simultaneousDownloads: 3,
        backendUrl: '',
        apiKey: '',
      );
      await settingsBox.put('app_settings', settings);
    }
    return settings;
  }

  @override
  Future<void> updateSettings(SettingsModel settings) async {
    await settingsBox.put('app_settings', settings);
  }
}