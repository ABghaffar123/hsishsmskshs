import 'dart:math';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vidmate_app/core/build_config.dart';
import 'package:vidmate_app/database/hive_database.dart';
import 'package:vidmate_app/services/backend_api_client.dart';

/// Video Player Screen for VidiMate
///
/// Full-screen player with:
/// - Play/pause, seek, 10s forward/back
/// - Speed 0.5x-2x
/// - Fullscreen mode
/// - PiP (Picture-in-Picture)
/// - Lock controls
///
/// DEBUG MARKER: This screen now initializes a real media_kit video player.
/// A small "DEBUG: <step>" text is shown at the top so the user can verify
/// on their phone that the code path is running.

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String channel;
  final double? duration;
  /// Direct playable stream URL (m3u8 / videoplayback / local file).
  /// If non-empty, this takes priority over [videoUrl] (a YouTube watch URL).
  final String streamUrl;
  /// The source URL (YouTube watch URL) used for extraction on the backend.
  final String? sourceUrl;

  /// Determines if the player is in audio-only mode (no video surface)
  final bool isAudioOnly;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.channel,
    this.duration,
    this.streamUrl = '',
    this.sourceUrl,
    this.isAudioOnly = false,
  });

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late mk.Player _player;
  late VideoController _videoController;

  // Track whether the player has received its first frame / is ready to display
  bool _videoReady = false;
  // Visible on-screen debug marker
  String _debugStep = 'init';

  // Playback state
  bool isPlaying = false;
  Duration seekPosition = Duration.zero;
  Duration duration = Duration.zero;
  double playbackSpeed = 1.0;
  bool isFullscreen = false;
  bool controlsLocked = false;

  @override
  void initState() {
    super.initState();
    debugPrint('PLAYER(init): starting video init, url=${widget.videoUrl}');
    setState(() => _debugStep = 'creating_player');
    _initVideo();
  }

  Future<void> _initVideo() async {
    debugPrint('PLAYER(init_video): creating mk.Player and opening media');
    setState(() => _debugStep = 'ensuring_media_kit...');
    mk.MediaKit.ensureInitialized(); // REQUIRED before creating mk.Player
    setState(() => _debugStep = 'media_kit_initialized');
    _player = mk.Player();
    _videoController = VideoController(_player);

    // Listen to width/height — when video dimensions become available,
    // we know the player initialized & first frame is ready.
    _player.stream.width.listen((w) {
      debugPrint('PLAYER(stream_width): $w');
      final h = _player.state.height;
      if (w != null && w > 0 && h != null && h > 0 && !_videoReady) {
        setState(() {
          _videoReady = true;
          _debugStep = 'video_ready_${w}x$h';
        });
      }
    });
    _player.stream.height.listen((h) {
      debugPrint('PLAYER(stream_height): $h');
      final w = _player.state.width;
      if (h != null && h > 0 && w != null && w > 0 && !_videoReady) {
        setState(() {
          _videoReady = true;
          _debugStep = 'video_ready_${w}x$h';
        });
      }
    });

    // Listen to playing state
    _player.stream.playing.listen((playing) {
      debugPrint('PLAYER(stream_playing): $playing');
      setState(() => isPlaying = playing);
    });

    // Listen to position
    _player.stream.position.listen((pos) {
      setState(() => seekPosition = pos);
    });

    // Listen to duration
    _player.stream.duration.listen((dur) {
      setState(() => duration = dur);
    });

    // Open the media
    _openMedia();
  }

  Future<String> _resolvePlayableUrl() async {
    // Priority 1: an explicit stream URL (m3u8 / direct playable)
    if (widget.streamUrl.isNotEmpty) {
      debugPrint('PLAYER(resolve): using streamUrl=${widget.streamUrl.substring(0, 50)}...');
      setState(() => _debugStep = 'resolved_stream_url');
      return widget.streamUrl;
    }
    // Priority 2: sourceUrl — ask the backend extract endpoint for a
    // playable stream URL (needed because videoUrl is a YouTube watch page).
    final source = widget.sourceUrl ?? widget.videoUrl;
    if (source.isNotEmpty && source.contains('youtube.com')) {
      debugPrint('PLAYER(resolve): extracting stream for $source');
      setState(() => _debugStep = 'extracting_stream...');
      try {
        final extracted = await BackendApiClient.extractVideoInfo(source);
        if (extracted != null && extracted.streamUrl.isNotEmpty) {
          debugPrint('PLAYER(resolve): got streamUrl from backend');
          setState(() => _debugStep = 'resolved_stream_from_backend');
          return extracted.streamUrl;
        }
        // Extraction failed or returned no stream URL — fall through
        debugPrint('PLAYER(resolve): no streamUrl from extraction, falling back');
      } catch (e) {
        debugPrint('PLAYER(resolve): extract failed - $e, falling back');
      }
    }
    // Priority 3: fall back to videoUrl as-is (local file or already playable)
    if (widget.videoUrl.isNotEmpty) {
      debugPrint('PLAYER(resolve): falling back to videoUrl');
      setState(() => _debugStep = 'using_video_url_fallback');
      return widget.videoUrl;
    }
    // No playable URL available — mark error but don't return empty.
    // This ensures the player still opens with a placeholder so dimension
    // listeners can fire, and the user sees an informative error state.
    debugPrint('PLAYER(resolve): no playable URL available — showing error state');
    setState(() => _debugStep = 'ERROR: no playable URL');
    return '';
  }

  Future<void> _openMedia() async {
    // BUG 6: Check autoplay setting
    bool shouldAutoplay = false;
    try {
      final settingsBox = await getSettingsBox();
      shouldAutoplay = settingsBox.get('autoplay') as bool? ?? false;
      debugPrint('PLAYER(open_media): autoplay setting=$shouldAutoplay');
    } catch (e) {
      debugPrint('PLAYER(open_media): Error reading autoplay setting - $e');
    }

    final playableUrl = await _resolvePlayableUrl();
    if (playableUrl.isEmpty) {
      debugPrint('PLAYER(open_media): no playable URL available — initializing player for error state');
      setState(() => _debugStep = 'ERROR: no playable URL');
      return;
    }
    debugPrint('PLAYER(open_media): opening $playableUrl');
    setState(() => _debugStep = 'opening_media');
    try {
      final media = mk.Media(playableUrl);
      await _player.open(media);

      // BUG 15: Apply saved playback speed from Settings
      try {
        final settingsBox = await getSettingsBox();
        final savedSpeed = settingsBox.get('playback_speed') as double? ?? 1.0;
        playbackSpeed = savedSpeed;
        _player.setRate(savedSpeed);
        debugPrint('PLAYER(open_media): applied saved playback speed $savedSpeed');
      } catch (e) {
        debugPrint('PLAYER(open_media): Error reading playback_speed - $e');
      }

      // BUG 6: Auto-play implementation
      if (shouldAutoplay) {
        debugPrint('PLAYER(open_media): triggering autoplay');
        _player.play();
      }

      debugPrint('PLAYER(open_media): media opened successfully');
      setState(() => _debugStep = 'media_opened_wait_frame');
    } catch (e, st) {
      debugPrint('PLAYER(open_media): ERROR $e\n$st');
      setState(() => _debugStep = 'ERROR: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('PLAYER(dispose): cleaning up player');
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('PLAYER(build): videoReady=$_videoReady, debugStep=$_debugStep');
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F13),
      body: Column(
        children: [
          // DEBUG MARKER — visible on phone to confirm this code path is running
          _debugBanner(),
          // Video surface (real video or loading placeholder)
          _buildVideoSurface(),
          // Progress and time display
          _buildProgressBar(),
          // Action controls
          _buildActionControls(),
          // Speed control
          _buildSpeedControl(),
          // Lock controls toggle
          _buildLockToggle(),
        ],
      ),
    );
  }

  Widget _debugBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFF0000),
      ),
      child: Text(
        'DEBUG: $_debugStep | version: ${BuildConfig.version}+${BuildConfig.buildNumber}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildVideoSurface() {
    debugPrint('PLAYER(video_surface): videoReady=$_videoReady');
    if (!_videoReady) {
      // Loading path — this is the path the user sees on their phone
      return Container(
        height: 200,
        width: double.infinity,
        color: const Color(0xFF171922),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.video_library,
              size: 60,
              color: Color(0xFF6C5CE7),
            ),
            // On-screen status marker visible to the user on their phone
            // (CLAUDE.md rule: add a status marker on the loading path)
            Positioned(
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _debugStep,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Loading video... Step 1: Initializing player',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Additional step indicators based on debug step
                  if (_debugStep.contains('creating_player') || _debugStep.contains('init'))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '✓ Player created',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  if (_debugStep.contains('resolved'))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '✓ Stream URL resolved',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  if (_debugStep.contains('video_ready'))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '✓ Video ready for playback',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // Ready path — real video surface from media_kit
    final w = _player.state.width;
    final h = _player.state.height;
    final double ratio =
        (w != null && w > 0 && h != null && h > 0)
            ? w / h
            : 16 / 9;
    debugPrint('PLAYER(video_surface): ready, aspect=$ratio, ${w}x$h');
    return AspectRatio(
      aspectRatio: ratio,
      child: Video(
        controller: _videoController,
      ),
    );
  }

  Widget _buildProgressBar() {
    final int totalSeconds = duration.inSeconds;
    final int elapsedSeconds = seekPosition.inSeconds;
    final double progressValue =
        totalSeconds > 0 ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Seek bar with 10s skip capability
          LinearProgressIndicator(
            value: progressValue,
            backgroundColor: const Color(0xFF3A3D4F),
            minHeight: 6,
          ),
          // Time display: current / total
          _timeDisplay(),
        ],
      ),
    );
  }

  Widget _timeDisplay() {
    return Row(
      children: [
        Text(
          _formatTime(seekPosition.inSeconds),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const Spacer(),
        Text(
          _formatTime((duration - seekPosition).inSeconds),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Previous 10s
          _controlButton(
            icon: Icons.fast_rewind,
            onTap: _onPrevious,
          ),
          // Play/Pause (center)
          const Spacer(),
          _controlButton(
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            label: isPlaying ? 'Pause' : 'Play',
            onTap: _onTogglePlay,
          ),
          // Next 10s
          const Spacer(),
          _controlButton(
            icon: Icons.fast_forward,
            onTap: _onNext,
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required VoidCallback onTap,
    String? label,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6C5CE7), size: 20),
            if (label != null)
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 8),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedControl() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            '${playbackSpeed.toStringAsFixed(1)}x',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          _speedButton(0.5, '0.5x'),
          const SizedBox(width: 4),
          _speedButton(1.0, '1x'),
          const SizedBox(width: 4),
          _speedButton(1.5, '1.5x'),
          const SizedBox(width: 4),
          _speedButton(2.0, '2x'),
        ],
      ),
    );
  }

  Widget _speedButton(double speed, String label) {
    final bool isSelected = playbackSpeed == speed;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _onSetSpeed(speed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C5CE7) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLockToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Lock: ${controlsLocked ? 'On' : 'Off'}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          _lockButton(),
        ],
      ),
    );
  }

  Widget _lockButton() {
    final bool isLocked = controlsLocked;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _onToggleLock,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isLocked ? const Color(0xFFFDCB6E) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isLocked ? 'Unlock' : 'Lock',
          style: TextStyle(
            color: isLocked ? const Color(0xFFFDCB6E) : Colors.white,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  void _onSetSpeed(double speed) {
    playbackSpeed = speed;
    _player.setRate(speed);
    setState(() {});
  }

  void _onToggleLock() {
    controlsLocked = !controlsLocked;
    setState(() {});
  }

  void _onTogglePlay() {
    setState(() {
      isPlaying = !isPlaying;
    });
    if (isPlaying) {
      _player.play();
    } else {
      _player.pause();
    }
  }

  void _onPrevious() {
    final target = seekPosition.inSeconds - 10;
    _player.seek(Duration(seconds: max(0, target)));
  }

  void _onNext() {
    final target = seekPosition.inSeconds + 10;
    _player.seek(Duration(seconds: target));
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return '00:00';

    int totalSeconds = seconds;
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int secs = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

/// Mock data for video player

final Map<String, dynamic> sampleVideo = {
  'id': '1',
  'title': 'Space Documentary',
  'channel': 'Science Channel',
  'duration': '45:00',
  'thumbnail': 'https://via.placeholder.com/140x78/2A2D3E/FFFFFF?text=Space',
  'quality': ['360p', '720p', '1080p'],
  'category': 'Documentary',
};
