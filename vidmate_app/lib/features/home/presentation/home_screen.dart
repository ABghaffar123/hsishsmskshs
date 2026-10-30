import 'dart:async'; // For Timer
import 'dart:io'; // For File

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:vidmate_app/core/error_handler.dart';
import 'package:vidmate_app/features/discover/data/backend_models.dart';
import 'package:vidmate_app/services/backend_api_client.dart';
import 'package:vidmate_app/database/hive_database.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _pasteLinkController = TextEditingController();
  bool _isDetecting = false;
  bool _isDownloading = false;
  String? _downloadJobId; // Track job ID for progress polling
  double _currentProgress = 0.0; // Real progress from backend (0.0 - 1.0)

  @override
  void initState() {
    super.initState();
    // Check clipboard on app open for auto-detection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardOnAppOpen();
    });
  }

  /// Validate that the pasted text looks like a usable video URL.
  /// Returns null when valid, or a user-facing reason string when not.
  String? _validateVideoUrl(String url) {
    if (url.isEmpty) {
      return 'Koi bhi URL paste nahi kiya.';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAbsolutePath) {
      return 'Yeh ek sahih URL nahi lagta. Video ka link paste karein.';
    }
    // Reject schemes that are definitely not video links.
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Sirf HTTP/HTTPS link support hota hai.';
    }
    return null; // valid
  }

  /// Check clipboard on app open for auto-detection
  Future<void> _checkClipboardOnAppOpen() async {
    // BUG 11 Fix: respect the user's clipboard_detection setting from Hive
    try {
      final settingsBox = await getSettingsBox();
      final clipboardDetection = settingsBox.get('clipboard_detection') as bool? ?? true;
      if (!clipboardDetection) {
        debugPrint('HOME: clipboard detection is disabled in settings');
        return;
      }
    } catch (e) {
      // Ignore settings read errors, default to allowed
    }

    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      final url = clipboardData.text!.trim();
      final validationError = _validateVideoUrl(url);
      if (validationError == null) {
        // Valid video URL detected in clipboard
        setState(() {
          _pasteLinkController.text = url;
        });
        // Show premium popup for quality selection
        _showClipboardPopup(url);
      }
    }
  }

  /// Show premium popup for clipboard detected link
  Future<void> _showClipboardPopup(String url) async {
    // Show quality selection dialog similar to manual paste
    final extracted = await BackendApiClient.extractVideoInfo(url);
    if (extracted == null) {
      _showErrorDialog(
        'Is link ka video extract nahi ho saka. Supported sites (YouTube, '
        'Twitter, Instagram, etc.) par try karein, ya URL check karein. '
        'Facebook/TikTok jaise kuch sites restricted ho sakte hain.',
        errorType: ErrorType.unknown,
      );
      return;
    }

    // Show quality selection dialog - use Navigator.of(context).pop(selectedQuality)
    final selectedQuality = await _showQualitySelectionDialog(context, extracted);
    if (!mounted) return;
    if (selectedQuality == null) {
      setState(() {
        _isDetecting = false;
      });
      return;
    }

    setState(() {
      _isDetecting = false;
      _isDownloading = true;
    });

    // Determine fileType: 'audio' if Audio Only selected, 'video' otherwise
    final fileType = selectedQuality == 'audio' ? 'audio' : 'video';

    // Use extracted.sourceUrl (the best available source URL) with selected quality and proper fileType
    final job = await BackendApiClient.startDownload(
      url: extracted.sourceUrl,
      quality: selectedQuality,
      fileType: fileType,
    );

    if (!mounted) return;
    if (job == null) {
      _showErrorDialog('Download start nahi ho saka. Internet check karein aur dobara try karein.');
      setState(() {
        _isDownloading = false;
      });
    } else {
      // Store job info for progress tracking
      _downloadJobId = job.jobId;
      _showSnackBar('Download started: ${job.title}');
      // Show downloading status on home screen
      setState(() {
        _isDownloading = true;
      });
      // Start progress polling
      _startProgressPolling(job.jobId);
    }
  }

  Future<void> _detectAndDownload({bool isAudioOnly = false}) async {
    debugPrint('HOME: _detectAndDownload called, isAudioOnly=$isAudioOnly');
    final url = _pasteLinkController.text.trim();

    // --- Problem 2 fix: validate the URL *before* hitting the backend so we
    // never send a malformed / unsupported link (e.g. Facebook) and trigger an
    // unhandled "Something Went Wrong" crash screen.
    final validationError = _validateVideoUrl(url);
    if (validationError != null) {
      debugPrint('HOME: URL validation failed - $validationError');
      _showErrorDialog(validationError, errorType: ErrorType.unknown);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isDetecting = true;
    });

    try {
      debugPrint('HOME: calling BackendApiClient.extractVideoInfo for $url');
      final extracted = await BackendApiClient.extractVideoInfo(url);
      if (!mounted) return;

      if (extracted == null) {
        // Backend returned no data — could be unsupported site or timeout.
        // Show friendly message without misleading "Something Went Wrong" title.
        _showErrorDialog(
          'Video fetch ho raha hai, abhi thora wait karein ya Get dabane se retry karein. '
          'Agar problem bar rahi ho to URL check karein ya supported site (YouTube, '
          'Twitter, Instagram) par try karein. Facebook/TikTok jaise kuch sites restricted ho sakte hain.',
          errorType: ErrorType.network,
        );
        setState(() {
          _isDetecting = false;
        });
        return;
      }

      // Show quality selection dialog - use Navigator.of(context).pop(selectedQuality)
      final selectedQuality = await _showQualitySelectionDialog(context, extracted);
      if (!mounted) return;
      if (selectedQuality == null) {
        setState(() {
          _isDetecting = false;
        });
        return;
      }

      setState(() {
        _isDetecting = false;
        _isDownloading = true;
      });

      // Determine fileType: 'audio' if Audio Only selected, 'video' otherwise
      final fileType = selectedQuality == 'audio' ? 'audio' : 'video';

      // Use extracted.sourceUrl with selected quality and proper fileType
      final job = await BackendApiClient.startDownload(
        url: extracted.sourceUrl,
        quality: selectedQuality,
        fileType: fileType,
      );

      if (!mounted) return;
      if (job == null) {
        _showErrorDialog('Download start nahi ho saka. Internet check karein aur dobara try karein.');
        setState(() {
          _isDownloading = false;
        });
      } else {
        // Store job info for progress tracking
        _downloadJobId = job.jobId;
        _showSnackBar('Download started: ${job.title}');
        // Show downloading status on home screen
        setState(() {
          _isDownloading = true;
        });
        // Start progress polling
        _startProgressPolling(job.jobId);
      }
    } catch (e, st) {
      // --- Problem 2 fix: broad catch-all that converts *any* exception
      // (DioException, SocketException, TypeError, etc.) into a friendly
      // dialog.  Previously an unhandled exception here would crash to the red
      // Flutter error screen showing "Something Went Wrong".
      debugPrint('HOME: _detectAndDownload catch - $e\n$st');
      ErrorHandler.logError(e, stackTrace: st);

      final errorType = ErrorHandler.getErrorType(e);
      String message;

      if (errorType == ErrorType.network || errorType == ErrorType.timeout) {
        message = 'Internet connection nahi mil raha. Apna Wi-Fi ya mobile data check karein.';
      } else if (errorType == ErrorType.server) {
        // Specifically call out Facebook / unsupported-link failures.
        message = 'Is link ka video extract nahi ho saka. Supported site par try karein ya URL check karein. '
                  '(Facebook/TikTok restricted ho sakte hain.)';
      } else {
        message = 'Kuch ghalat ho gaya. Dobara try karein ya URL check karein.';
      }

      if (mounted) {
        _showErrorDialog(message, errorType: errorType);
      }
    } finally {
      if (mounted) {
        // Only clear _isDetecting — _isDownloading must stay true if a
        // download actually started (polling is running).
        // FIX Bug 1: Do NOT reset _isDownloading here if a job was started.
        // The UI visibility depends on _downloadJobId, not _isDownloading.
        setState(() {
          _isDetecting = false;
        });
      }
    }
  }

  /// Start progress polling for a download job
  void _startProgressPolling(String jobId) {
    // Initial status check
    _pollDownloadStatus(jobId);
    // Poll every 3 seconds while downloading, then stop on completion/failure
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!this.mounted) {
        timer.cancel();
        return;
      }
      _pollDownloadStatus(jobId);
    });
  }

  /// Poll download status from backend
  Future<void> _pollDownloadStatus(String jobId) async {
    if (!mounted) return;
    try {
      final job = await BackendApiClient.getDownloadStatus(jobId);
      if (!mounted) return;
      if (job != null) {
        // Update download progress in Hive for persistence
        try {
          final box = Hive.box<DownloadModel>('downloads');
          // Find existing download or create new entry
          final existing = box.values.firstWhere((d) => d.id == jobId);
          // Update the existing entry
          if (existing.id.isNotEmpty) {
            box.put(existing.id, DownloadModel(
              id: job.jobId,
              title: job.title,
              thumbnail: job.thumbnail,
              sourceUrl: job.sourceUrl,
              quality: job.quality,
              fileType: job.fileType,
              size: job.size,
              status: job.status,
              progress: job.progress,
              speed: job.speed,
              eta: job.eta,
              filePath: job.filePath,
              duration: '${job.progress * 100}.0', // Convert progress to percentage
              dates: existing.dates,
              error: job.error,
            ));
          }
        } catch (e) {
          debugPrint('HOME: Failed to save download status to Hive - $e');
        }

        // Show progress in snack bar if status changed
        // FIX Bug 2: Cancel the progress timer on completed/failed status
        if (job.status == 'completed') {
          // FIX Bug 2: Cancel the progress timer on completed status
          _progressTimer?.cancel();
          _progressTimer = null;
          // FIX Bug 1: Also clear _downloadJobId so UI indicator disappears
          // FIX Bug 3: Download the completed file from backend
          _downloadCompletedFile(job);
          if (mounted) {
            setState(() {
              _downloadJobId = null;
            });
            _showSnackBar('Download complete: ${job.title}');
          }
        } else if (job.status == 'failed') {
          // FIX Bug 2: Cancel the progress timer on failed status
          _progressTimer?.cancel();
          _progressTimer = null;
          // FIX Bug 1: Also clear _downloadJobId so UI indicator disappears
          if (mounted) {
            setState(() {
              _downloadJobId = null;
            });
            _showSnackBar('Download failed: ${job.error}');
          }
        } else if (job.status == 'paused') {
          if (mounted) {
            _showSnackBar('Download paused: ${job.title}');
          }
        } else {
          // Update real progress from backend (downloading/pending)
          if (mounted) {
            setState(() {
              _currentProgress = job.progress;
            });
          }
        }
      } else {
        // Job not found - stop polling
        _progressTimer?.cancel();
        _progressTimer = null;
      }
    } catch (e) {
      debugPrint('HOME: Polling error for job $jobId - $e');
      // Continue polling on network errors
    }
  }

  /// Download the completed file from backend
  Future<void> _downloadCompletedFile(DownloadJobModel job) async {
    try {
      debugPrint('HOME: Downloading completed file for job ${job.jobId}');
      final savedPath = await BackendApiClient.getDownloadFile(job.jobId);
      if (savedPath != null && savedPath.isNotEmpty) {
        // Get actual file size using File(path).length()
        final file = File(savedPath);
        final actualSize = await file.length();
        debugPrint('HOME: File downloaded successfully, path: $savedPath, size: $actualSize bytes');
        _showSnackBar('Video downloaded: ${job.title} (${(actualSize / 1024 / 1024).toStringAsFixed(1)} MB)');
      } else {
        debugPrint('HOME: No file path returned for job ${job.jobId}');
        _showSnackBar('Download complete but file could not be saved: ${job.title}');
      }
    } catch (e) {
      debugPrint('HOME: Failed to download completed file for job ${job.jobId} - $e');
      _showSnackBar('Download complete but error saving file: ${job.title}');
    }
  }

  Timer? _progressTimer;

  Future<String?> _showQualitySelectionDialog(
      BuildContext context, ExtractedVideoModel video) async {
    String? selectedQuality;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2D3E),
          // FIX Problem 1: wrap title in Flexible + maxLines + ellipsis so a
          // long video title (e.g. Facebook) never overflows ("RIGHT OVERFLOWED
          // BY 11 PIXELS").
          title: Tooltip(
            message: video.title,
            child: Text(
              video.title,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...video.qualities.map((quality) => RadioListTile<String>(
                      value: quality,
                      groupValue: selectedQuality,
                      title: Text(quality, style: TextStyle(color: Colors.white)),
                      onChanged: (value) {
                        setState(() {
                          selectedQuality = value;
                        });
                        // Use Navigator.of(context).pop(selectedQuality) to return the selected quality
                        Navigator.of(context).pop(selectedQuality);
                      },
                    )),
                RadioListTile<String>(
                  value: 'audio',
                  groupValue: selectedQuality,
                  title: const Text('Audio Only', style: TextStyle(color: Colors.white)),
                  onChanged: (value) {
                    setState(() {
                      selectedQuality = value;
                    });
                    // Use Navigator.of(context).pop(selectedQuality) to return the selected quality
                    Navigator.of(context).pop(selectedQuality);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message, {ErrorType? errorType}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3E),
        title: Row(
          children: [
            if (errorType != null) ...[
              Icon(getErrorIcon(errorType), color: Color(0xFF6C5CE7), size: 24),
              const SizedBox(width: 8),
            ],
            Text(
              errorType != null ? getErrorTitle(errorType) : 'Error',
              style: TextStyle(color: errorType == ErrorType.network || errorType == ErrorType.server ? Colors.red : Colors.white),
            ),
          ],
        ),
        // FIX Problem 1: constrain the error message so a long string never
        // overflows the dialog ("RIGHT OVERFLOWED BY 11 PIXELS").
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white70),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('OK'),
          ),
          if (errorType == ErrorType.network || errorType == ErrorType.timeout || errorType == ErrorType.server)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _detectAndDownload();
              },
              child: Text('Retry', style: TextStyle(color: Color(0xFF6C5CE7))),
            ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFF6C5CE7) : Colors.black87,
      ),
    );
  }

  // Auto-detect from clipboard
  Future<void> _handleGetButton() async {
    // Check clipboard for video URL
    await _checkClipboard();

    // Use the pasted link if available, otherwise show the dialog with manual entry
    final url = _pasteLinkController.text.trim();
    if (url.isNotEmpty) {
      await _detectAndDownload();
    } else {
      // Show info about clipboard detection
      _showSnackBar('Clipboard par video link detect kiya gaya hai. Get click karein.');
    }
  }

  Future<void> _checkClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      final url = clipboardData.text!.trim();
      if (_validateVideoUrl(url) == null) {
        _pasteLinkController.text = url;
        setState(() {});
        _showSnackBar('Clipboard par link copy kiya gaya: $url');
      }
    }
  }

  Widget _buildRecentDownloads(BuildContext context) {
    return FutureBuilder(
      future: _getRecentDownloads(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1C2B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No recent downloads',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          );
        }
        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) => _buildRecentDownloadCard(context, items[index]),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getRecentDownloads() async {
    // Read completed downloads from Hive
    try {
      final box = Hive.box<DownloadModel>('downloads');
      final completed = box.values.where((d) => d.status == 'completed').toList();
      // Sort by completion time descending
      completed.sort((a, b) {
        final aTime = a.dates['completedAt'] as String? ?? '';
        final bTime = b.dates['completedAt'] as String? ?? '';
        return bTime.compareTo(aTime);
      });
      // Take only 6 most recent
      final recent = completed.take(6).toList();

      return recent.map((d) => {
        'title': d.title,
        'progress': d.progress,
        'thumbnail': d.thumbnail,
        'status': d.status,
        'jobId': d.id,
        'quality': d.quality,
        'fileType': d.fileType,
      }).toList();
    } catch (e) {
      debugPrint('HOME: _getRecentDownloads error - $e');
      return [];
    }
  }

  Widget _buildRecentDownloadCard(BuildContext context, Map<String, dynamic> item) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1A1C2B),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.white10,
            ),
            child: const Icon(Icons.download, size: 24, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            item['title'] ?? 'Unknown',
            style: const TextStyle(color: Colors.white, fontSize: 8),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${item['progress'] ?? 0}%',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('HOME: build() called, isOffline=${BackendApiClient.isOffline}, baseUrl=${BackendApiClient.baseUrl}');
    return Scaffold(
      appBar: buildAppBar(context),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Paste Link Card
                _buildPasteLinkCard(context),
                const SizedBox(height: 16),

                // Recent Downloads
                _buildSectionTitle(context, 'Recent Downloads'),
                const SizedBox(height: 8),
                _buildRecentDownloads(context),
              ],
            ),
          ),
          // ─── Backend status marker (debug visibility) ─────────────────
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: BackendApiClient.isOffline
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF2ED573),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                BackendApiClient.isOffline ? 'OFFLINE' : 'ONLINE',
                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // ─── Download progress indicator ───────────────────────────────
          // FIX Bug 1: Show indicator based on _downloadJobId (not _isDownloading)
          // so it persists even if _isDownloading is reset in finally block.
          if (_downloadJobId != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xFF2A2D3E),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const CircularProgressIndicator(
                      color: Color(0xFF6C5CE7),
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentProgress > 0 ? '${(_currentProgress * 100).toStringAsFixed(1)}%' : 'Downloading...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // Cancel the download via backend
                        if (_downloadJobId != null) {
                          BackendApiClient.cancelDownload(_downloadJobId!);
                          // FIX Bug 2: Cancel the polling timer before resetting state
                          _progressTimer?.cancel();
                          _progressTimer = null;
                          // FIX Bug 1: Clear _downloadJobId so UI indicator disappears
                          if (mounted) {
                            setState(() {
                              _isDownloading = false;
                              _downloadJobId = null;
                            });
                          }
                        }
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF6C5CE7), fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      title: const Row(
        children: [
          Text('VM', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(width: 4),
          Text('VidiMate', style: TextStyle(fontSize: 18)),
        ],
      ),
      // Removed search and notification icons per VIDIMATE_HOME_DOWNLOAD_HISTORY_REFRESH_FIX.md
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        // Removed "See all" button per VIDIMATE_HOME_DOWNLOAD_HISTORY_REFRESH_FIX.md
      ],
    );
  }

  // Paste Link Card
  Widget _buildPasteLinkCard(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A3D4F), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste Link',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _buildPasteField(),
            const SizedBox(height: 8),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPasteField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3A3D4F), width: 1),
      ),
      child: TextField(
        controller: _pasteLinkController,
        decoration: const InputDecoration(
          hintText: 'Paste video URL here...',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isDetecting || _isDownloading ? null : _handleGetButton,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
            ),
            child: _isDetecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Get'),
          ),
        ),
      ],
    );
  }
}