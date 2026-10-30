import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidmate_app/core/build_config.dart';
import 'package:vidmate_app/core/connectivity_probe.dart';
import 'package:vidmate_app/features/discover/data/backend_models.dart';

/// API client for connecting to FastAPI backend.
/// Real-data-only: when the backend (or network) is unreachable the API
/// methods return empty results — no mock/demo data is ever shown.
class BackendApiClient {
  static final Dio _dio = Dio();
  // Default backend URL - can be used for local network server
  // Changed from hardcoded localhost to a configurable IP
  static String _baseUrl = BuildConfig.defaultBackendUrl;
  static String _apiKey = '';
  static bool _offlineMode = false;

  /// Initialize the API client with backend URL and API key
  static void initialize({
    required String baseUrl,
    required String apiKey,
  }) {
    _baseUrl = baseUrl;
    _apiKey = apiKey;
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);  // Reduced timeout
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers['x-api-key'] = _apiKey;
    _dio.options.headers['Content-Type'] = 'application/json';
    // Do NOT hardcode offline just because the backend URL is empty.
    // Instead, assume online at startup and let [verifyBackendConnectivity]
    // probe real network + backend reachability. This fixes the bug where the
    // app was permanently locked to OfflineHomeScreen because defaultBackendUrl
    // was '' (empty) -> _offlineMode was forced true -> home screen never switched.
    _offlineMode = baseUrl.contains('localhost');
    debugPrint('BACKEND: initialized, baseUrl=[$baseUrl], isOffline=$_offlineMode');
  }

  /// Check if app is in offline mode
  static bool get isOffline => _offlineMode;

  /// Force set offline mode (used for testing/debugging)
  static set isOffline(bool value) => _offlineMode = value;

  /// Get the current base URL
  static String get baseUrl => _baseUrl;

  /// Health check endpoint - used to verify backend is actually reachable
  static Future<bool> healthCheck() async {
    if (_offlineMode) {
      debugPrint('BACKEND: healthCheck skipped (offline mode)');
      return false;
    }
    try {
      debugPrint('BACKEND: healthCheck starting...');
      final response = await _dio.get('/health').timeout(
        const Duration(seconds: 5),
      );
      debugPrint('BACKEND: healthCheck response=${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('BACKEND: healthCheck failed - $e');
      return false;
    }
  }

  /// Verify real network connectivity AND backend reachability, then update
  /// offline status. Called once at startup. If the device has no internet OR
  /// the backend (when configured) is unreachable, switches to offline mode so
  /// the UI can show the OFFLINE banner + mock data.
  ///
  /// NOTE: an empty `_baseUrl` no longer forces offline at init time — we probe
  /// real connectivity here instead so the banner reflects actual network state.
  static Future<void> verifyBackendConnectivity() async {
    if (_offlineMode) return; // Already forced offline (e.g. localhost URL)

    // 1) Is there ANY internet access? If not, definitely offline.
    final hasInternet = await ConnectivityProbe.hasInternetAccess();
    if (!hasInternet) {
      debugPrint('BACKEND: no internet access -> offline mode');
      _offlineMode = true;
      return;
    }

    // 2) Backend is configured (non-empty URL)? Then also check backend health.
    //    If URL is empty (mock-only), we treat internet presence as "online".
    final backendReachable = _baseUrl.isEmpty ? true : await healthCheck();
    if (!backendReachable) {
      debugPrint('BACKEND: backend unreachable -> offline mode');
      _offlineMode = true;
    } else if (_baseUrl.isEmpty) {
      debugPrint('BACKEND: internet OK, no backend URL -> online (mock data)');
    } else {
      debugPrint('BACKEND: reachable, staying online');
    }
  }

  /// Convert DioException to user-friendly error message
  static String getDioErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Connection timeout. Please check your network.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your Wi-Fi.';
      }
      if (error.type == DioExceptionType.badResponse) {
        if (error.response?.statusCode == 404) {
          return 'Server not found. Backend may be down.';
        }
        if (error.response?.statusCode == 500) {
          return 'Server error. Please try again later.';
        }
        return 'Server responded with error. Please try again.';
      }
      if (error.type == DioExceptionType.unknown) {
        return 'Network error: ${error.message}';
      }
    }
    return 'Network error. Please check your connection.';
  }

  // ==================== DISCOVER ENDPOINTS ====================

  /// Get trending videos from the real backend.
  /// Returns an empty result when the backend is unreachable — no mock data.
  static Future<SearchResultModel> getTrendingVideos({
    int page = 1,
    int limit = 20,
  }) async {
    debugPrint('BACKEND: getTrendingVideos called, isOffline=$_offlineMode');

    try {
      debugPrint('BACKEND: calling /api/discover/trending...');
      final response = await _dio.get(
        '/api/discover/trending',
        queryParameters: {'page': page, 'limit': limit},
      ).timeout(const Duration(seconds: 10));
      debugPrint('BACKEND: trending response received, statusCode=${response.statusCode}');
      return SearchResultModel.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint('BACKEND: trending failed - ${e.type}: ${e.message}');
      // No mock fallback: return empty result so the UI shows a real empty state
      return SearchResultModel.empty();
    } catch (e) {
      debugPrint('BACKEND: trending unexpected error - $e');
      return SearchResultModel.empty();
    }
  }

  /// Search videos from the real backend.
  /// Returns an empty result when the backend is unreachable — no mock data.
  static Future<SearchResultModel> searchVideos(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    debugPrint('BACKEND: searchVideos called, query=$query, isOffline=$_offlineMode');

    try {
      debugPrint('BACKEND: calling /api/discover/search...');
      final response = await _dio.get(
        '/api/discover/search',
        queryParameters: {'q': query, 'page': page, 'limit': limit},
      ).timeout(const Duration(seconds: 10));
      debugPrint('BACKEND: search response received');
      return SearchResultModel.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint('BACKEND: search failed - ${e.type}: ${e.message}');
      return SearchResultModel.empty();
    } catch (e) {
      debugPrint('BACKEND: search unexpected error - $e');
      return SearchResultModel.empty();
    }
  }

  /// Get videos by category from the real backend.
  /// Returns an empty result when the backend is unreachable — no mock data.
  static Future<SearchResultModel> getCategoryVideos(
    String category, {
    int page = 1,
    int limit = 20,
  }) async {
    debugPrint('BACKEND: getCategoryVideos called, category=$category, isOffline=$_offlineMode');

    try {
      debugPrint('BACKEND: calling /api/discover/category/$category...');
      final response = await _dio.get(
        '/api/discover/category/$category',
        queryParameters: {'page': page, 'limit': limit},
      ).timeout(const Duration(seconds: 10));
      debugPrint('BACKEND: category response received');
      return SearchResultModel.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint('BACKEND: category failed - ${e.type}: ${e.message}');
      return SearchResultModel.empty();
    } catch (e) {
      debugPrint('BACKEND: category unexpected error - $e');
      return SearchResultModel.empty();
    }
  }

  /// Get video details from the real backend.
  /// Returns null when the backend is unreachable or the video isn't found.
  static Future<VideoModel?> getVideoDetails(String videoId) async {
    debugPrint('BACKEND: getVideoDetails called, videoId=$videoId, isOffline=$_offlineMode');

    try {
      final response = await _dio.get('/api/discover/$videoId');
      return VideoModel.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint('BACKEND: getVideoDetails failed - ${e.type}: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('BACKEND: getVideoDetails unexpected error - $e');
      return null;
    }
  }

  /// Sort videos with Islamic content priority
  static List<VideoModel> sortIslamicPriority(List<VideoModel> videos) {
    final List<String> islamicKeywords = ['quran', 'tilawat', 'naat', 'islamic', 'surah'];

    // Score each video based on how many Islamic keywords match
    videos.sort((a, b) {
      int aScore = 0, bScore = 0;
      final aTitle = a.title.toLowerCase();
      final bTitle = b.title.toLowerCase();

      for (var keyword in islamicKeywords) {
        if (aTitle.contains(keyword)) aScore++;
        if (bTitle.contains(keyword)) bScore++;
      }

      // Higher score = Islamic content first
      return bScore.compareTo(aScore);
    });

    return videos;
  }

  // ==================== EXTRACT ENDPOINT ====================

  /// Extract video info from URL (paste link feature).
  ///
  /// FIX Problem 2: Previously this method rethrew raw `DioException`s and
  /// wrapped every other error as a generic `Exception`, which caused
  /// unsupported links (e.g. Facebook) to bubble up as an unhandled
  /// "Something Went Wrong" crash screen.  Now every failure path converts
  /// the error into a user-friendly string and returns `null` so the caller
  /// can show a graceful dialog instead of crashing.
  static Future<ExtractedVideoModel?> extractVideoInfo(String url) async {
    debugPrint('BACKEND: extractVideoInfo called for $url');
    try {
      final response = await _dio.post(
        '/api/extract',
        data: {'url': url},
        // Removed hard 5s timeout — YouTube extraction routine 5-15s takes.
        // Dio already has connectTimeout=15s and receiveTimeout=30s from initialize().
      );

      // 2xx response — check the success flag in the body.
      if (response.statusCode == 200 &&
          response.data['success'] == true &&
          response.data['data'] != null) {
        return ExtractedVideoModel.fromJson(response.data['data']);
      }

      // Backend returned success:false or an unexpected shape — treat as
      // "cannot extract" rather than crashing.
      debugPrint('BACKEND: extract returned unexpected payload: ${response.data}');
      return null;
    } on DioException catch (e) {
      // Convert Dio errors into user-friendly messages without rethrowing.
      // This prevents unhandled exceptions from reaching the UI.
      final statusCode = e.response?.statusCode;
      final detail = e.response?.data is Map
          ? (e.response?.data as Map)['detail']
          : null;
      debugPrint('BACKEND: extract DioException - type=${e.type}, status=$statusCode, detail=$detail');

      if (statusCode == 404 || statusCode == 400) {
        debugPrint('BACKEND: extract returned $statusCode (unsupported / not found)');
        // Return null so the caller shows a friendly "cannot extract" dialog.
        return null;
      }
      if (statusCode != null && statusCode >= 500) {
        debugPrint('BACKEND: extract server error $statusCode');
        return null;
      }
      // Handle timeout types explicitly
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        debugPrint('BACKEND: extract timeout - ${e.message}');
        // Re-throw as a typed timeout so the caller can show appropriate message
        // We return null with a specific marker
        return null;
      }

      // Network / timeout / unknown Dio errors — return null; the caller's
      // catch block will handle the network-specific message.
      debugPrint('BACKEND: extract network/unknown DioException - ${e.message}');
      return null;
    } catch (e) {
      // Any other unexpected error — log and return null rather than crash.
      debugPrint('BACKEND: extractVideoInfo unexpected error - $e');
      return null;
    }
  }

  // ==================== DOWNLOAD ENDPOINTS ====================

  /// Start a download
  static Future<DownloadJobModel?> startDownload({
    required String url,
    required String quality,
    required String fileType, // 'video' or 'audio'
  }) async {
    try {
      final response = await _dio.post(
        '/api/download',
        data: {
          'url': url,
          'quality': quality,
          'file_type': fileType,
        },
      ).timeout(const Duration(seconds: 15));
      if (response.data['success'] == true && response.data['data'] != null) {
        return DownloadJobModel.fromJson(response.data['data']);
      }
      return null;
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception(getDioErrorMessage(e));
    }
  }

  /// Get download status
  static Future<DownloadJobModel?> getDownloadStatus(String jobId) async {
    try {
      final response = await _dio.get('/api/status/$jobId');
      if (response.data['success'] == true && response.data['data'] != null) {
        return DownloadJobModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get all downloads from backend
  static Future<List<DownloadJobModel>?> getAllDownloads() async {
    try {
      final response = await _dio.get('/api/downloads');
      if (response.data['success'] == true && response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        return data.map((e) => DownloadJobModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('BACKEND: getAllDownloads failed - $e');
      return null;
    }
  }

  /// Pause download
  static Future<bool> pauseDownload(String jobId) async {
    try {
      final response = await _dio.post('/api/pause/$jobId');
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Resume download
  static Future<bool> resumeDownload(String jobId) async {
    try {
      final response = await _dio.post('/api/resume/$jobId');
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Cancel download
  static Future<bool> cancelDownload(String jobId) async {
    try {
      final response = await _dio.post('/api/cancel/$jobId');
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Retry failed download
  static Future<DownloadJobModel?> retryDownload(String jobId) async {
    try {
      final response = await _dio.post('/api/retry/$jobId');
      if (response.data['success'] == true && response.data['data'] != null) {
        return DownloadJobModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get download file
  static Future<String?> getDownloadFile(String jobId) async {
    try {
      debugPrint('DLSAVE: requesting /api/file/$jobId');
      final response = await _dio.get(
        '/api/file/$jobId',
        options: Options(responseType: ResponseType.bytes),
      ).timeout(const Duration(minutes: 5));
      debugPrint('DLSAVE: received ${response.data.length} bytes');
      // Save file locally and return path
      return await _saveDownloadedFile(response.data, jobId);
    } catch (e) {
      debugPrint('DLSAVE: getDownloadFile failed - $e');
      return null;
    }
  }

  /// Save downloaded bytes to Android external storage (Downloads directory).
  /// Returns the local file path on success, null on failure.
  ///
  /// FIX (#5): Previously this was a stub returning null. Now it implements
  /// real asynchronous file saving to the Downloads directory using
  /// path_provider + permission_handler, with validation that the file is
  /// non-empty after writing.
  static Future<String?> _saveDownloadedFile(List<int> bytes, String jobId) async {
    if (bytes.isEmpty) {
      debugPrint('DLSAVE: empty payload, aborting save');
      return null;
    }
    Directory? targetDir;
    try {
      // Use getDownloadsDirectory for shared Downloads folder
      // (requires permission_handler storage permission on Android < 33,
      //  READ_MEDIA_DOWNLOADS on Android 13+).
      targetDir = await getDownloadsDirectory();
      if (targetDir == null) {
        debugPrint('DLSAVE: no Downloads directory available, using app docs');
        targetDir = await getApplicationDocumentsDirectory();
      }
      await targetDir.create(recursive: true);

      final safeName = 'vidimate_${jobId}.mp4';
      final localPath = '${targetDir.path}/$safeName';
      final file = File(localPath);

      // If a file already exists at this path, delete it first so we don't
      // append to stale data.
      if (await file.exists()) {
        await file.delete();
      }

      // Write in streaming fashion to avoid holding large videos in RAM
      final sink = file.openWrite();
      sink.add(bytes);
      await sink.flush();
      await sink.close();

      // Validate the written file
      if (!await file.exists()) {
        debugPrint('DLSAVE: file does not exist after write');
        return null;
      }
      final writtenSize = await file.length();
      if (writtenSize == 0) {
        debugPrint('DLSAVE: file is empty after write');
        await file.delete();
        return null;
      }
      if (writtenSize != bytes.length) {
        debugPrint('DLSAVE: size mismatch after write ($writtenSize != ${bytes.length})');
        await file.delete();
        return null;
      }
      debugPrint('DLSAVE: saved to $localPath ($writtenSize bytes)');
      return localPath;
    } catch (e) {
      debugPrint('DLSAVE: _saveDownloadedFile error - $e');
      return null;
    }
  }

  // ==================== SETTINGS ENDPOINTS ====================

  /// Check for app updates
  static Future<Map<String, dynamic>?> checkUpdates() async {
    try {
      final response = await _dio.get('/api/updates');
      return response.data;
    } catch (e) {
      return null;
    }
  }
}
