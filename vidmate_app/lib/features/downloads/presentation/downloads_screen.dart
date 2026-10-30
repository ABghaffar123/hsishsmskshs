import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

import 'package:vidmate_app/core/error_handler.dart';
import 'package:vidmate_app/services/backend_api_client.dart';
import 'package:vidmate_app/database/hive_database.dart';
import 'package:vidmate_app/features/discover/data/backend_models.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadModel> _downloads = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';
  bool _refreshInProgress = false;
  Timer? _pollingSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('DOWNLOADS: initState called');
    _loadLocalDownloads();
    _refreshDownloads(); // Initial refresh from backend

    // Periodic polling every 2 seconds
    _pollingSubscription = Timer.periodic(Duration(seconds: 2), (timer) {
      if (mounted && !_refreshInProgress) {
        _refreshDownloads();
      }
    });
  }

  @override
  void dispose() {
    _pollingSubscription?.cancel();
    super.dispose();
  }

  /// Load downloads from local Hive storage immediately
  Future<void> _loadLocalDownloads() async {
    try {
      final box = Hive.box<DownloadModel>('downloads');
      final localDownloads = box.values.toList();
      // Sort by updated time descending
      localDownloads.sort((a, b) {
        final aUpdate = a.dates['updatedAt'] as String? ?? '';
        final bUpdate = b.dates['updatedAt'] as String? ?? '';
        return bUpdate.compareTo(aUpdate);
      });
      setState(() {
        _downloads = localDownloads;
        _isLoading = false;
      });
      debugPrint('DOWNLOADS: loaded ${localDownloads.length} local downloads');
    } catch (e) {
      debugPrint('DOWNLOADS: local load failed - $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Refresh downloads from backend, merging with local Hive data
  Future<void> _refreshDownloads() async {
    // Prevent duplicate refresh requests
    if (_refreshInProgress) {
      debugPrint('DOWNLOADS: refresh already in progress, skipping');
      return;
    }

    setState(() {
      _refreshInProgress = true;
      _errorMessage = '';
    });

    try {
      debugPrint('DOWNLOADS: _refreshDownloads called');

      // Try to fetch from backend
      final backendDownloads = await BackendApiClient.getAllDownloads();

      if (!mounted) return;

      if (backendDownloads != null && backendDownloads.isNotEmpty) {
        await _mergeBackendDownloads(backendDownloads);
      }

      // Always reload from local storage to reflect any merges
      await _loadLocalDownloads();

      debugPrint('DOWNLOADS: refresh complete');
    } catch (e) {
      debugPrint('DOWNLOADS: refresh failed - $e');
      // Keep showing local downloads on backend failure
      setState(() {
        _errorMessage = 'backend_offline';
      });
      await _loadLocalDownloads();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _refreshInProgress = false;
        });
      }
    }
  }

  /// Verify that a completed file actually exists, is non-empty, and is readable.
  /// Returns true if the file is valid; false otherwise. On failure, sets an
  /// error message in the DownloadModel so the UI can show a retry option.
  static Future<bool> _verifyFileExists(String filePath) async {
    if (filePath.isEmpty) return false;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('VERIFY: file does not exist at $filePath');
        return false;
      }
      final length = await file.length();
      if (length <= 0) {
        debugPrint('VERIFY: file is empty at $filePath');
        return false;
      }
      // Try opening the file for reading to confirm it is accessible
      final stream = file.openRead();
      await stream.first;
      debugPrint('VERIFY: file verified ok at $filePath ($length bytes)');
      return true;
    } catch (e) {
      debugPrint('VERIFY: file verification failed for $filePath - $e');
      return false;
    }
  }

  /// Merge backend download data with local Hive records
  Future<void> _mergeBackendDownloads(List<DownloadJobModel> backendJobs) async {
    final box = Hive.box<DownloadModel>('downloads');

    for (final job in backendJobs) {
      final existing = box.get(job.jobId);
      if (existing != null) {
        // When status changes to 'completed', verify the file actually exists
        // FIX: Previously, Hive completion status was set without verifying the
        // actual file was present. Now we validate before marking completed.
        String verifiedStatus = job.status;
        String verifiedError = job.error;

        if (job.status == 'completed' && job.filePath.isNotEmpty) {
          debugPrint('VERIFY: checking completed file for job ${job.jobId}');
          final valid = await _verifyFileExists(job.filePath);
          if (!valid) {
            verifiedStatus = 'failed';
            verifiedError = 'File missing or invalid after download';
            debugPrint('VERIFY: marking job ${job.jobId} as failed - file invalid');
          } else {
            // Add to MediaStore
            // TODO: Add MediaStore registration after download
// await LibraryVideoService.addToMediaStore(job.filePath, isVideo: true);
          }
        }

        // Update existing record
        final updated = DownloadModel(
          id: existing.id,
          title: job.title,
          sourceUrl: job.sourceUrl,
          thumbnail: job.thumbnail,
          quality: job.quality,
          fileType: job.fileType,
          filePath: job.filePath,
          size: job.size,
          duration: existing.duration,
          status: verifiedStatus,
          progress: job.progress,
          speed: job.speed,
          eta: job.eta,
          dates: Map<String, dynamic>.from(existing.dates)
            ..['updatedAt'] = DateTime.now().toIso8601String()
            ..['completedAt'] = verifiedStatus == 'completed'
                ? DateTime.now().toIso8601String()
                : existing.dates['completedAt'],
          error: verifiedError.isNotEmpty ? verifiedError : job.error,
        );
        await box.put(job.jobId, updated);
      } else {
        // New backend job - also verify completed files
        String verifiedStatus = job.status;
        String verifiedError = job.error;

        if (job.status == 'completed' && job.filePath.isNotEmpty) {
          final valid = await _verifyFileExists(job.filePath);
          if (!valid) {
            verifiedStatus = 'failed';
            verifiedError = 'File missing or invalid after download';
          }
        }

        final newDownload = DownloadModel(
          id: job.jobId,
          title: job.title,
          sourceUrl: job.sourceUrl,
          thumbnail: job.thumbnail,
          quality: job.quality,
          fileType: job.fileType,
          filePath: job.filePath,
          size: job.size,
          duration: '', // DownloadJobModel has no duration field
          status: verifiedStatus,
          progress: job.progress,
          speed: job.speed,
          eta: job.eta,
          dates: {
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          error: verifiedError.isNotEmpty ? verifiedError : job.error,
        );
        await box.put(job.jobId, newDownload);
      }
    }
  }

  Future<void> _pauseDownload(String jobId) async {
    try {
      await BackendApiClient.pauseDownload(jobId);
      _refreshDownloads();
    } catch (e) {
      ErrorHandler.logError(e);
      _showErrorSnackBar(ErrorHandler.getFriendlyMessage(e));
    }
  }

  Future<void> _resumeDownload(String jobId) async {
    try {
      await BackendApiClient.resumeDownload(jobId);
      _refreshDownloads();
    } catch (e) {
      ErrorHandler.logError(e);
      _showErrorSnackBar(ErrorHandler.getFriendlyMessage(e));
    }
  }

  Future<void> _cancelDownload(String jobId) async {
    try {
      await BackendApiClient.cancelDownload(jobId);
      _refreshDownloads();
    } catch (e) {
      ErrorHandler.logError(e);
      _showErrorSnackBar(ErrorHandler.getFriendlyMessage(e));
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6C5Ce7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('DOWNLOADS: build() called, isOffline=${BackendApiClient.isOffline}, count=${_downloads.length}');
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshDownloads,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _isLoading && _downloads.isEmpty
                      ? _buildSkeletonList()
                      : _errorMessage.isNotEmpty && _downloads.isEmpty
                          ? _buildErrorState()
                          : _downloads.isEmpty
                              ? _buildEmptyState()
                              : _buildDownloadsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Downloads'),
      actions: [
        IconButton(
          icon: _isRefreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                )
              : const Icon(Icons.refresh_outlined),
          tooltip: 'Refresh',
          onPressed: _isRefreshing ? null : _refreshDownloads,
        ),
      ],
    );
  }

  /// Content-matched skeleton for download rows
  Widget _buildSkeletonList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[700]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail + title row
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 10,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            height: 10,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                Container(
                  width: double.infinity,
                  height: 4,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                // Status row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 80,
                      height: 8,
                      color: Colors.white,
                    ),
                    Container(
                      width: 60,
                      height: 8,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    final errorType = ErrorType.network;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              getErrorIcon(errorType),
              color: const Color(0xFF6C5Ce7),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              getErrorTitle(errorType),
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Backend se data lena fail ho gaya. Local downloads dikhayi de sakti hain.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshDownloads,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5Ce7),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 40),
          Icon(Icons.download_done, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No active or recent downloads',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Paste a link in Home or Discover to start downloading',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _downloads.length,
      itemBuilder: (context, index) {
        final download = _downloads[index];
        return _buildDownloadItem(download);
      },
    );
  }

  Widget _buildDownloadItem(DownloadModel download) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFF2A2D3E),
                ),
                child: download.thumbnail.isNotEmpty
                    ? Image.network(
                        download.thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.video_library, color: Colors.grey);
                        },
                      )
                    : const Icon(Icons.video_library, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.title,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${download.quality} • ${download.status}',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: download.progress,
            backgroundColor: Color(0xFF3A3D4F),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(download.progress * 100).toInt()}% • ${download.speed.toStringAsFixed(1)} MB/s',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
              Row(
                children: [
                  if (download.status == 'downloading')
                    TextButton(
                      onPressed: () => _pauseDownload(download.id),
                      child: Text('Pause', style: TextStyle(fontSize: 10)),
                    ),
                  if (download.status == 'paused')
                    TextButton(
                      onPressed: () => _resumeDownload(download.id),
                      child: Text('Resume', style: TextStyle(fontSize: 10)),
                    ),
                  TextButton(
                    onPressed: () => _cancelDownload(download.id),
                    child: Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 10)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
