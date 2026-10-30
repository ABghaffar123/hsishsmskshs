import 'dart:io';

import 'package:flutter/material.dart';

import 'package:vidmate_app/features/library/data/library_video_service.dart';
import 'package:vidmate_app/features/player/presentation/video_player_from_file_screen.dart';
import 'package:vidmate_app/services/backend_api_client.dart';
import 'package:vidmate_app/database/hive_database.dart';

/// State management for Library screen - tracks current view (folders/list)
enum LibraryViewMode { folders, videoList, audioList }

/// State class to hold Library data across tab switches
class LibraryDataState {
  List<LocalMediaFile>? videos;
  List<LocalMediaFile>? audioFiles;
  List<MediaFolder>? videoFolders;
  DateTime? lastScanTime;
  bool isLoading = false;
  String? errorMessage;
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedTabIndex = 0;
  LibraryViewMode _videoViewMode = LibraryViewMode.folders;
  final LibraryDataState _libraryState = LibraryDataState();
  String _currentSortOption = 'Recent';
  final List<String> _sortOptions = ['Recent', 'Name', 'Size', 'Duration'];
  final List<String> _searchHistory = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initLibrary();
  }

  Future<void> _initLibrary() async {
    // NOTE: downloads/favorites boxes are already opened by initHive() in
    // main.dart (typed). Re-opening them here untyped causes a type-mismatch
    // crash ("Box is already open with type X"). Use the safe accessors only.
    _scanLibrary();
  }

  Future<void> _scanLibrary({bool forceRefresh = false}) async {
    if (_libraryState.isLoading) return;

    setState(() {
      _libraryState.isLoading = true;
      _libraryState.errorMessage = null;
    });

    try {
      final videos = await LibraryVideoService.scanPhoneVideos(forceRefresh: forceRefresh);
      final audioFiles = await LibraryVideoService.scanPhoneAudio(forceRefresh: forceRefresh);

      setState(() {
        _libraryState.videos = videos;
        _libraryState.audioFiles = audioFiles;
        _libraryState.lastScanTime = DateTime.now();
        _libraryState.isLoading = false;
      });
    } catch (e) {
      debugPrint('LIBRARY: scan error - $e');
      setState(() {
        _libraryState.errorMessage = e.toString();
        _libraryState.isLoading = false;
      });
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
      _searchQuery = '';
    });
  }

  List<Widget> get _tabs => [
    _buildVideosTab(),
    _buildAudioTab(),
    _buildFavoritesTab(),
    _buildWatchLaterTab(),
    _buildPrivateVaultTab(),
  ];

  @override
  Widget build(BuildContext context) {
    debugPrint('LIBRARY: build() called, viewMode=$_videoViewMode, hasVideos=${_libraryState.videos?.length}, hasFolders=${_libraryState.videoFolders?.length}');

    final tabs = ['Videos', 'Audio', 'Favorites', 'Watch Later', 'Private Vault'];
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search bar
              _buildSearchBar(),
              const SizedBox(height: 8),
              // Tabs
              _buildTabs(context, tabs),
              const SizedBox(height: 8),
              // Tab content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _tabs[_selectedTabIndex],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Library'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => _scanLibrary(forceRefresh: true),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: 'More options',
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        decoration: InputDecoration(
          hintText: 'Search in this tab...',
          hintStyle: TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildTabs(BuildContext context, List<String> tabs) {
    return Container(
      height: 40,
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          int index = entry.key;
          String label = entry.value;
          final bool isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onTabSelected(index),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Videos Tab ───────────────────────────────────────────────────────────

  Widget _buildVideosTab() {
    if (_libraryState.isLoading && _libraryState.videos == null) {
      return _buildLoadingState();
    }

    if (_libraryState.errorMessage != null) {
      return _buildErrorState(_libraryState.errorMessage!);
    }

    if (_libraryState.videos == null) {
      // Permission denied
      return _buildPermissionMessage(isAudio: false);
    }

    if (_videoViewMode == LibraryViewMode.folders) {
      return _buildVideoFoldersView();
    }

    return _buildVideoListView();
  }

  Future<List<MediaFolder>?> _getVideoFolders() async {
    if (_libraryState.videoFolders != null) return _libraryState.videoFolders;
    final videos = _libraryState.videos;
    if (videos == null) return null;

    // Group videos by folder
    final Map<String, List<LocalMediaFile>> folderMap = {};
    for (final video in videos) {
      final folderPath = video.folderPath;
      if (!folderMap.containsKey(folderPath)) {
        folderMap[folderPath] = [];
      }
      folderMap[folderPath]!.add(video);
    }

    final folders = <MediaFolder>[];
    for (final entry in folderMap.entries) {
      final files = entry.value;
      final name = entry.key.split(Platform.pathSeparator).last;
      folders.add(MediaFolder(
        id: entry.key,
        name: name.isEmpty ? 'Storage Root' : name,
        path: entry.key,
        videoCount: files.length,
      ));
    }

    folders.sort((a, b) => b.videoCount.compareTo(a.videoCount));
    _libraryState.videoFolders = folders;
    return folders;
  }

  Widget _buildVideoFoldersView() {
    if (_libraryState.videos == null || _libraryState.videos!.isEmpty) {
      return _buildEmptyState(isAudio: false, message: 'No video files found');
    }

    return FutureBuilder<List<MediaFolder>?>(
      future: _getVideoFolders(),
      builder: (context, snapshot) {
        final folders = snapshot.data;
        if (folders == null || folders.isEmpty) {
          return _buildEmptyState(isAudio: false, message: 'No folders found');
        }

        final filteredFolders = _searchQuery.isEmpty
            ? folders
            : folders.where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

        return RefreshIndicator(
          onRefresh: () => _scanLibrary(forceRefresh: true),
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: filteredFolders.length,
            itemBuilder: (context, index) {
              final folder = filteredFolders[index];
              return _buildFolderCard(folder);
            },
          ),
        );
      },
    );
  }

  Widget _buildFolderCard(MediaFolder folder) {
    return GestureDetector(
      onTap: () {
        // Navigate to folder's video list
        final folderVideos = _libraryState.videos!
            .where((v) => v.folderPath == folder.path)
            .toList();
        setState(() {
          _videoViewMode = LibraryViewMode.videoList;
          _searchQuery = '';
        });
        _showFolderVideos(folder.name, folderVideos);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C2B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3A3D4F), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2D3E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Icon(Icons.folder, color: Color(0xFF6C5CE7), size: 36),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${folder.videoCount} videos',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderVideos(String folderName, List<LocalMediaFile> videos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C2B),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 8, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(folderName, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: videos.length,
                itemBuilder: (context, index) => _buildVideoListItem(videos[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoListView() {
    final videos = _searchQuery.isEmpty
        ? _libraryState.videos!
        : _libraryState.videos!.where((v) => v.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (videos.isEmpty) {
      return _buildEmptyState(isAudio: false, message: 'No videos in this folder');
    }

    return RefreshIndicator(
      onRefresh: () => _scanLibrary(forceRefresh: true),
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: videos.length + 1,
        separatorBuilder: (context, index) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == videos.length) {
            return SizedBox(height: 16);
          }
          return _buildVideoListItem(videos[index]);
        },
      ),
    );
  }

  Widget _buildVideoListItem(LocalMediaFile video) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D3E),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.videocam, color: Colors.white70, size: 24),
      ),
      title: Text(video.title, style: TextStyle(color: Colors.white)),
      subtitle: Text('${_formatFileSize(video.size)} • ${_formatDuration(video.duration)}', style: TextStyle(color: Colors.white70, fontSize: 12)),
      trailing: IconButton(
        icon: Icon(Icons.download, color: const Color(0xFF6C5CE7)),
        onPressed: () => _startDownload(video),
      ),
      onTap: () => _navigateToPlayer(video),
    );
  }

  // ─── Audio Tab ──────────────────────────────────────────────────────────────

  Widget _buildAudioTab() {
    if (_libraryState.isLoading && _libraryState.audioFiles == null) {
      return _buildLoadingState();
    }

    final audioFiles = _libraryState.audioFiles;
    if (audioFiles == null) {
      return _buildPermissionMessage(isAudio: true);
    }

    final filtered = _searchQuery.isEmpty
        ? audioFiles
        : audioFiles.where((v) => v.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(isAudio: true, message: 'No audio files found');
    }

    return RefreshIndicator(
      onRefresh: () => _scanLibrary(forceRefresh: true),
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: filtered.length + 1,
        separatorBuilder: (context, index) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            return SizedBox(height: 16);
          }
          return _buildAudioListItem(filtered[index]);
        },
      ),
    );
  }

  Widget _buildAudioListItem(LocalMediaFile audio) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D3E),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.music_note, color: Color(0xFF6C5CE7), size: 24),
      ),
      title: Text(audio.title, style: TextStyle(color: Colors.white)),
      subtitle: Text('${_formatFileSize(audio.size)} • ${_formatDuration(audio.duration)}', style: TextStyle(color: Colors.white70, fontSize: 12)),
      trailing: IconButton(
        icon: Icon(Icons.download, color: const Color(0xFF6C5CE7)),
        onPressed: () => _startDownload(audio),
      ),
      onTap: () => _navigateToPlayer(audio),
    );
  }

  // ─── Other Tabs ─────────────────────────────────────────────────────────────

  Widget _buildFavoritesTab() {
    return FutureBuilder(
      future: _getFavoritedFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        final files = snapshot.data ?? [];
        if (files.isEmpty) {
          return Center(
            child: Text('No favorites yet', style: TextStyle(color: Colors.white70)),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return ListTile(
              leading: Icon(Icons.favorite, color: Colors.red),
              title: Text(file['title'] ?? 'Unknown', style: TextStyle(color: Colors.white)),
              onTap: () {},
            );
          },
        );
      },
    );
  }

  Widget _buildWatchLaterTab() {
    return Center(
      child: Text('Watch Later list will appear here', style: TextStyle(color: Colors.white70)),
    );
  }

  Widget _buildPrivateVaultTab() {
    return const Center(
      child: Text('Private vault is locked', style: TextStyle(color: Colors.white70)),
    );
  }

  // ─── Common Widgets ─────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF6C5CE7)),
          SizedBox(height: 16),
          Text('Scanning your media...', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFF6C5Ce7), size: 48),
            const SizedBox(height: 16),
            const Text('Error Loading Files', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Files load nahi ho sakke hain. Permission check karein ya phone ko restart karein.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _scanLibrary(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5Ce7),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isAudio, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isAudio ? Icons.music_note : Icons.video_library, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.white70, fontSize: 16)),
          SizedBox(height: 8),
          Text('No accessible media files found', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPermissionMessage({required bool isAudio}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isAudio ? Icons.music_off : Icons.folder_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              isAudio ? 'Audio files dikh nahi rahe?' : 'Videos dikh nahi rahe?',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              isAudio
                  ? 'Audio permission dein, tabhi audio files show honge.'
                  : 'Storage permission accept karein, videos show hona start ho jayengi.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (isAudio) {
                  await LibraryVideoService.requestAudioPermission();
                } else {
                  await LibraryVideoService.requestStoragePermission();
                }
                _scanLibrary(forceRefresh: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5Ce7),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(isAudio ? 'Grant Audio Permission' : 'Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Download & Navigation ──────────────────────────────────────────────────

  Future<void> _startDownload(LocalMediaFile mediaFile) async {
    // Use the local path directly for download
    final job = await BackendApiClient.startDownload(
      url: mediaFile.path,
      quality: 'original',
      fileType: mediaFile.isVideo ? 'video' : 'audio',
    );

    if (!mounted) return;
    if (job == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed'), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download started: ${job.title}'), backgroundColor: const Color(0xFF6C5Ce7)),
      );
    }
  }

  void _navigateToPlayer(LocalMediaFile mediaFile) {
    debugPrint('LIBRARY: navigating to player for ${mediaFile.path}');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerFromFileScreen(filePath: mediaFile.path),
      ),
    );
  }

  // ─── Helper methods ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _getFavoritedFiles() async {
    // Use the typed safe accessor — never openBox('favorites') directly,
    // it is already opened by initHive() in main.dart.
    final box = await getFavoritesBox();
    final List<Map<String, dynamic>> items = [];
    for (var i = 0; i < box.length; i++) {
      final data = box.getAt(i) as Map?;
      if (data != null) {
        items.add(Map<String, dynamic>.from(data));
      }
    }
    return items;
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
