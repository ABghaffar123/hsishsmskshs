import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Audio Player Screen for VidiMate
///
/// Mini player with:
/// - Play/pause, next/previous, seek
/// - Background audio
/// - Notification controls
/// - Repeat/shuffle optional

class AudioPlayerScreen extends StatefulWidget {
  final List<String> audioFiles;
  final int initialIndex;
  final String? initialFile;

  const AudioPlayerScreen({
    super.key,
    required this.audioFiles,
    this.initialIndex = 0,
    this.initialFile,
  });

  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer audioPlayer;
  bool isPlaying = false;
  Duration seekPosition = Duration.zero;
  Duration duration = Duration.zero;
  double playbackSpeed = 1.0;
  bool isRepeat = false;
  bool isShuffle = false;
  String? currentFile;

  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayer();
    audioPlayer.playerStateStream.listen(_onPlaybackStateChange);
    audioPlayer.positionStream.listen(_onPositionChange);
    audioPlayer.durationStream.listen(_onDurationChange);
    _initAudio();
  }

  Future<void> _initAudio() async {
    if (widget.initialFile != null && widget.audioFiles.contains(widget.initialFile)) {
      final idx = widget.audioFiles.indexOf(widget.initialFile!);
      await audioPlayer.setFilePath(widget.audioFiles[idx]);
      currentFile = widget.audioFiles[idx];
    } else {
      await audioPlayer.setFilePath(widget.audioFiles[widget.initialIndex]);
      currentFile = widget.audioFiles[widget.initialIndex];
    }
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  void _onPlaybackStateChange(PlayerState state) {
    setState(() {
      isPlaying = state.playing;
    });
  }

  void _onPositionChange(Duration position) {
    setState(() {
      seekPosition = position;
    });
  }

  void _onDurationChange(Duration? d) {
    setState(() {
      duration = d ?? Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F13),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Now playing info
        _buildNowPlaying(),

        // Progress bar
        _buildProgressBar(),

        // Controls
        _buildControls(),

        // Speed, repeat, shuffle
        _buildSettings(),
      ],
    );
  }

  Widget _buildNowPlaying() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.music_note,
            color: Color(0xFF6C5CE7),
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              currentFile ?? 'No file',
              style: const TextStyle(color: Colors.white, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: duration.inSeconds > 0 ? seekPosition.inSeconds / duration.inSeconds : 0,
            backgroundColor: const Color(0xFF3A3D4F),
            minHeight: 4,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(seekPosition.inSeconds),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _formatTime((duration - seekPosition).inSeconds),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
            onPressed: _onPrevious,
            tooltip: 'Previous',
          ),

          // Play/Pause (center, larger)
          const Spacer(),
          IconButton(
            icon: isPlaying ? const Icon(Icons.pause, color: Colors.white) : const Icon(Icons.play_arrow, color: Colors.white),
            onPressed: _onTogglePlay,
            tooltip: isPlaying ? 'Pause' : 'Play',
            iconSize: 48,
          ),
          const Spacer(),

          // Next
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 20),
            onPressed: _onNext,
            tooltip: 'Next',
          ),
        ],
      ),
    );
  }

  void _onTogglePlay() {
    setState(() {
      isPlaying = !isPlaying;
    });
    if (isPlaying) {
      audioPlayer.play();
    } else {
      audioPlayer.pause();
    }
  }

  Widget _buildSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _settingItem(
            icon: Icons.repeat,
            label: isRepeat ? 'On' : 'Off',
            onTap: _onToggleRepeat,
          ),
          const SizedBox(width: 8),
          _settingItem(
            icon: Icons.shuffle,
            label: isShuffle ? 'On' : 'Off',
            onTap: _onToggleShuffle,
          ),
        ],
      ),
    );
  }

  Widget _settingItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D3E),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6C5CE7), size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  void _onToggleRepeat() {
    setState(() {
      isRepeat = !isRepeat;
    });
    // TODO: implement repeat
  }

  void _onToggleShuffle() {
    setState(() {
      isShuffle = !isShuffle;
    });
    // TODO: implement shuffle
  }

  void _onPrevious() {
    audioPlayer.seek(Duration.zero);
  }

  void _onNext() {
    audioPlayer.seek(Duration.zero);
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