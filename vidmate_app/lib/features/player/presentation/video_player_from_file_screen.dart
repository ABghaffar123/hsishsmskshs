import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Video Player Screen for playing a video from a file path.
///
/// Uses [media_kit] + [media_kit_video] to play the video.
class VideoPlayerFromFileScreen extends StatefulWidget {
  final String filePath;

  const VideoPlayerFromFileScreen({
    Key? key,
    required this.filePath,
  }) : super(key: key);

  @override
  State<VideoPlayerFromFileScreen> createState() =>
      _VideoPlayerFromFileScreenState();
}

class _VideoPlayerFromFileScreenState extends State<VideoPlayerFromFileScreen> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    // Initialize media_kit if not already done.
    MediaKit.ensureInitialized();
    _player = Player();
    _controller = VideoController(_player);

    // Set the media to the file.
    _player.open(Media(
      widget.filePath,
    ));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Video(
            controller: _controller,
          ),
        ),
      ),
    );
  }
}