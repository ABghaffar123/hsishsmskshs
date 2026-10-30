import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../data/backend_models.dart';
import 'package:vidmate_app/services/backend_api_client.dart';
import 'package:vidmate_app/features/discover/data/mock_discover.dart';
import 'package:vidmate_app/features/player/presentation/video_player_screen.dart';
import 'package:vidmate_app/core/error_handler.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _currentFilter = 'Trending';
  int _currentPage = 1;
  final int _pageSize = 5; // Reduced for pagination visibility
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<VideoModel> _videos = [];
  String _lastSearchQuery = '';
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  Future<SearchResultModel>? _videosFuture;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController.addListener(_onScroll);
    _loadTrendingVideos();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreVideos();
      }
    }
  }

  Future<void> _loadTrendingVideos() async {
    debugPrint('DISCOVER: _loadTrendingVideos called, isOffline=${BackendApiClient.isOffline}');
    setState(() {
      _currentPage = 1;
      _videos = [];
      _hasMore = true;
      _currentFilter = 'Trending';
      _lastSearchQuery = '';
      _searchController.clear();
      _videosFuture = _loadTrendingWithIslamicPriority();
    });
  }

  Future<SearchResultModel> _loadTrendingWithIslamicPriority() async {
    debugPrint('DISCOVER: _loadTrendingWithIslamicPriority started');
      try {
      final result = await BackendApiClient.getTrendingVideos(
        page: _currentPage,
        limit: _pageSize,
      );
      // Sort Islamic content to the top
      final sortedVideos = BackendApiClient.sortIslamicPriority(result.videos);

      setState(() {
        for (var video in sortedVideos) {
          if (!_videos.any((v) => v.id == video.id)) {
            _videos.add(video);
          }
        }
        _hasMore = _videos.length < result.total && sortedVideos.isNotEmpty;
      });

      return result;
    } catch (e) {
      debugPrint('DISCOVER: _loadTrendingWithIslamicPriority catch - $e');
      // OFFLINE FALLBACK
      final fallback = MockDiscoverData.getTrendingResult(
        page: _currentPage,
        limit: _pageSize,
      );
      setState(() {
        for (var video in fallback.videos) {
          if (!_videos.any((v) => v.id == video.id)) {
            _videos.add(video);
          }
        }
        _hasMore = fallback.videos.length < fallback.total && fallback.videos.isNotEmpty;
      });
      return fallback;
    }
  }

  void _onSearchChanged(String query) {
    // Debounce: cancel previous timer and restart with 300ms delay
    _debounceTimer?.cancel();
    if (query.length >= 3) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _searchVideos(query);
      });
    } else if (query.isEmpty) {
      _loadTrendingVideos();
    }
  }

  Future<void> _searchVideos(String query) async {
    debugPrint('DISCOVER: _searchVideos called, query=$query');
    setState(() {
      _currentPage = 1;
      _videos = [];
      _hasMore = true;
      _lastSearchQuery = query;
      _videosFuture = _loadSearchWithErrorHandling(query);
    });
  }

  Future<SearchResultModel> _loadSearchWithErrorHandling(String query) async {
    try {
      final result = await BackendApiClient.searchVideos(
        query,
        page: _currentPage,
        limit: _pageSize,
      );

      setState(() {
        for (var video in result.videos) {
          if (!_videos.any((v) => v.id == video.id)) {
            _videos.add(video);
          }
        }
        _hasMore = _videos.length < result.total && result.videos.isNotEmpty;
      });

      return result;
    } catch (e) {
      debugPrint('DISCOVER: _loadSearchWithErrorHandling catch - $e');
      // OFFLINE FALLBACK
      final fallback = MockDiscoverData.searchResult(
        query,
        page: _currentPage,
        limit: _pageSize,
      );
      setState(() {
        for (var video in fallback.videos) {
          if (!_videos.any((v) => v.id == video.id)) {
            _videos.add(video);
          }
        }
        _hasMore = fallback.videos.length < fallback.total && fallback.videos.isNotEmpty;
      });
      return fallback;
    }
  }

  Future<void> _loadCategoryVideos(String category) async {
    debugPrint('DISCOVER: _loadCategoryVideos called, category=$category');
    setState(() {
      _currentPage = 1;
      _videos = [];
      _hasMore = true;
      _currentFilter = category;
      _lastSearchQuery = '';
      _videosFuture = _loadCategoryWithErrorHandling(category);
    });
  }

  Future<SearchResultModel> _loadCategoryWithErrorHandling(String category) async {
    try {
      final result = await BackendApiClient.getCategoryVideos(
        category,
        page: _currentPage,
        limit: _pageSize,
      );

      setState(() {
        for (var video in result.videos) {
          if (!_videos.any((v) => v.id == video.id)) {
            _videos.add(video);
          }
        }
        _hasMore = _videos.length < result.total && result.videos.isNotEmpty;
      });

      return result;
    } catch (e) {
      debugPrint('DISCOVER: _loadCategoryWithErrorHandling catch - $e');
      // OFFLINE FALLBACK
      final fallback = MockDiscoverData.getCategoryVideos(_currentFilter);
      final pageStart = (_currentPage - 1) * _pageSize;
      final pageEnd = (pageStart + _pageSize).clamp(0, fallback.length);
      final pageVideos = fallback.sublist(pageStart, pageEnd);
      setState(() {
        for (var video in pageVideos) {
          if (!_videos.any((v) => v.id == video.id)) {
            _videos.add(video);
          }
        }
        _hasMore = pageVideos.length == _pageSize;
      });
      return SearchResultModel(
        videos: pageVideos,
        total: fallback.length,
        query: _currentFilter,
        page: _currentPage,
        limit: _pageSize,
      );
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMore) return;

    debugPrint('DISCOVER: _loadMoreVideos called, page=${_currentPage + 1}');
    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      SearchResultModel result;

      if (_lastSearchQuery.isNotEmpty) {
        result = await BackendApiClient.searchVideos(
          _lastSearchQuery,
          page: _currentPage,
          limit: _pageSize,
        );
      } else if (_currentFilter != 'Trending') {
        result = await BackendApiClient.getCategoryVideos(
          _currentFilter,
          page: _currentPage,
          limit: _pageSize,
        );
      } else {
        result = await BackendApiClient.getTrendingVideos(
          page: _currentPage,
          limit: _pageSize,
        );
      }

      setState(() {
        final newVideos = result.videos;
        if (newVideos.isEmpty) {
          _hasMore = false;
        } else {
          for (var video in newVideos) {
            if (!_videos.any((v) => v.id == video.id)) {
              _videos.add(video);
            }
          }
          _hasMore = _videos.length < result.total;
        }
        _isLoadingMore = false;
      });
      debugPrint('DISCOVER: _loadMoreVideos done, total videos=${_videos.length}, hasMore=$_hasMore');
    } catch (e) {
      debugPrint('DISCOVER: _loadMoreVideos catch - $e');
      setState(() {
        _isLoadingMore = false;
      });
      _showSnackBar('Next page load karne mein masla hua.');
    }
  }

  /// Single smooth shimmer sweep across ENTIRE screen (not per-card).
  /// Cards match real `_buildTrendingVideoCard` layout: 16:9 thumbnail
  /// (120w x 72h) + title lines (right).
  Widget _buildTrendingSkeleton() {
    debugPrint('SKELETON: _buildTrendingSkeleton called');
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail placeholder: 120w x 72h (matches real card)
              Container(
                width: 120,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 6),
              // Text lines (right side)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title line: full width, two short lines
                    Container(
                      width: double.infinity,
                      height: 10,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 10,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Channel/views line: shorter
                    Container(
                      width: 80,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    // Only show real error - not for empty successful results
    // Check if this looks like a real API error vs empty data
    final isRealError = error.isNotEmpty &&
        !error.toLowerCase().contains('no videos') &&
        !error.toLowerCase().contains('empty');

    if (!isRealError) {
      // Treat as empty state, not error
      return _emptyState(context);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: const Color(0xFF6C5CE7),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTrendingVideos,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
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

  Widget _emptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library, color: Colors.grey, size: 64),
          SizedBox(height: 16),
          Text('No videos found', style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _errorState(BuildContext context, String error) {
    // Only show real error - not for empty successful results
    // Check if this looks like a real API error vs empty data
    final isRealError = error.isNotEmpty &&
        !error.toLowerCase().contains('no videos') &&
        !error.toLowerCase().contains('empty');

    if (!isRealError) {
      // Treat as empty state, not error
      return _emptyState(context);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: const Color(0xFF6C5CE7),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadTrendingVideos(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
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

  @override
  Widget build(BuildContext context) {
    // DEBUG MARKER - visible on screen to verify this build path is running
    debugPrint('DISCOVER: build() called, isOffline=${BackendApiClient.isOffline}');
    return Scaffold(
      appBar: _buildAppBar(context),
      body: FutureBuilder<SearchResultModel>(
        future: _videosFuture,
        builder: (context, snapshot) {
          final bool isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
          // Single smooth shimmer sweep across ENTIRE screen (not per-card).
          return Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[700]!,
            period: const Duration(milliseconds: 1500),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: isLoading
                  ? _buildSkeletonScreen(context)
                  : _buildContentScreen(context, snapshot),
            ),
          );
        },
      ),
    );
  }

  /// Full-screen skeleton layout matching the real content dimensions.
  Widget _buildSkeletonScreen(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 24),
          _buildCategoryChipsSkeleton(),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Featured'),
          const SizedBox(height: 8),
          _buildFeaturedBannerSkeleton(),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Trending Now'),
          const SizedBox(height: 8),
          _buildTrendingSkeleton(),
        ],
      ),
    );
  }

  /// Real content shown after fade transition when data loads.
  Widget _buildContentScreen(BuildContext context, AsyncSnapshot<SearchResultModel> snapshot) {
    // We use the _videos list instead of snapshot.data directly for pagination support
    if (_videos.isEmpty && snapshot.connectionState == ConnectionState.done) {
      if (snapshot.hasError) {
        return _errorState(context, snapshot.error.toString());
      }
      return _emptyState(context);
    }

    return RefreshIndicator(
      onRefresh: _loadTrendingVideos,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 24),
            _buildCategoryChips(),
            const SizedBox(height: 24),
            if (_videos.isNotEmpty) ...[
              _buildSectionTitle(context, 'Featured'),
              const SizedBox(height: 8),
              _buildFeaturedBanner(context),
              const SizedBox(height: 24),
            ],
            _buildSectionTitle(context, _lastSearchQuery.isNotEmpty ? 'Search Results' : 'Trending Now'),
            const SizedBox(height: 8),
            _buildTrendingList(),
            const SizedBox(height: 24),
            if (_isLoadingMore) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (!_hasMore && _videos.length > 5) ...[
              const Center(
                child: Text(
                  'Aur videos nahi hain.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Discover'),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search videos...',
          hintStyle: TextStyle(color: Colors.white54),
          prefixIcon: Icon(Icons.search, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCategoryChips() {
    final List<String> categories = [
      'Trending',
      'Music',
      'News',
      'Movies',
      'Gaming',
      'Sports',
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _currentFilter == category;
          return GestureDetector(
            onTap: () => _loadCategoryVideos(category),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6C5CE7) : const Color(0xFF1A1C2B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF6C5CE7) : const Color(0xFF3A3D4F),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Featured banner skeleton: box placeholder with shimmer sweep.
  /// Category chips skeleton: horizontal placeholders.
  Widget _buildCategoryChipsSkeleton() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            width: 72,
          );
        },
      ),
    );
  }

  /// Featured banner skeleton: box placeholder with shimmer sweep.
  Widget _buildFeaturedBannerSkeleton() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildFeaturedBanner(BuildContext context) {
    if (_videos.isEmpty) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C2B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library, size: 32, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Featured Video',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    final video = _videos.first;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: video.videoUrl,
              streamUrl: video.streamUrl,
              sourceUrl: video.sourceUrl,
              title: video.title,
              channel: video.channel,
            ),
          ),
        );
      },
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C2B),
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(video.thumbnail),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            ),
          ),
          padding: const EdgeInsets.all(12),
          alignment: Alignment.bottomLeft,
          child: Text(
            video.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingList() {
    if (_videos.isEmpty) {
      return _buildTrendingSkeleton();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return _buildTrendingVideoCard(context, video);
      },
    );
  }

  Widget _buildTrendingVideoCard(BuildContext context, VideoModel video) {
    return GestureDetector(
      onTap: () {
        debugPrint('DISCOVER: video tapped - ${video.title}');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: video.videoUrl,
              streamUrl: video.streamUrl,
              sourceUrl: video.sourceUrl,
              title: video.title,
              channel: video.channel,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1A1C2B),
          border: Border.all(color: const Color(0xFF2A2D3E)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoThumbnail(context, video.thumbnail),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.channel} • ${_formatViews(video.viewCount)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildDownloadButton(video),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(VideoModel video) {
    return ElevatedButton.icon(
      onPressed: () => _startDownload(video),
      icon: const Icon(Icons.download, size: 14, color: Colors.white),
      label: const Text('Get', style: TextStyle(color: Colors.white, fontSize: 8)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C5CE7),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.fromHeight(28),
      ),
    );
  }

  Future<void> _startDownload(VideoModel video) async {
    final selectedQuality = video.qualities.isNotEmpty ? video.qualities.first : '720p';
    final job = await BackendApiClient.startDownload(
      url: video.sourceUrl,
      quality: selectedQuality,
      fileType: 'video',
    );
    if (job != null) {
      _showSnackBar('Download started: ${job.title}');
    } else {
      _showErrorDialog('Download start nahi ho saka. Dobara try karein.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6C5CE7),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3E),
        title: const Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoThumbnail(BuildContext context, String thumbnailUrl) {
    return Container(
      height: 72,
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFF2A2D3E),
      ),
      child: thumbnailUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                thumbnailUrl,
                width: 120,
                height: 72,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return shimmerPlaceholder();
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.video_library, size: 20, color: Colors.grey),
                  );
                },
              ),
            )
          : const Center(
              child: Icon(Icons.video_library, size: 20, color: Colors.grey),
            ),
    );
  }

  Widget shimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: Container(
        width: 120,
        height: 72,
        color: Colors.white,
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M views';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K views';
    }
    return '$views views';
  }
}
