import 'package:vidmate_app/features/discover/data/backend_models.dart';

// OFFLINE FALLBACK — real backend se replace hota hai, fail par use hota hai
/// Mock data for Discover screen
/// Used as fallback when backend is unreachable or in offline mode

class MockDiscoverData {
  static List<VideoModel> getTrendingVideos() {
    return [
      VideoModel(
        id: 'mock_1',
        title: 'Flutter Development Tutorial - Part 1',
        channel: 'CodeWithAndrea',
        thumbnail: 'https://via.placeholder.com/140x78/2A2D3E/FFFFFF?text=Flutter',
        duration: 1200,
        viewCount: 150000,
        category: 'Education',
        qualities: ['360p', '720p', '1080p'],
        sourceUrl: 'https://example.com/video1',
        videoUrl: 'https://test-streams.mux.dev/x36xfh64.mp4',
      ),
      VideoModel(
        id: 'mock_2',
        title: 'Building Beautiful Apps with Flutter',
        channel: 'The Net Ninja',
        thumbnail: 'https://via.placeholder.com/140x78/2A2D3E/FFFFFF?text=App+Design',
        duration: 900,
        viewCount: 89000,
        category: 'Education',
        qualities: ['360p', '720p'],
        sourceUrl: 'https://example.com/video2',
        videoUrl: 'https://test-streams.mux.dev/x36xfh64.mp4',
      ),
      VideoModel(
        id: 'mock_3',
        title: 'State Management in Flutter - Riverpod vs Provider',
        channel: 'Flutter Community',
        thumbnail: 'https://via.placeholder.com/140x78/2A2D3E/FFFFFF?text=Riverpod',
        duration: 1800,
        viewCount: 230000,
        category: 'Education',
        qualities: ['360p', '720p', '1080p', '4K'],
        sourceUrl: 'https://example.com/video3',
        videoUrl: 'https://test-streams.mux.dev/x36xfh64.mp4',
      ),
      VideoModel(
        id: 'mock_4',
        title: 'Firebase for Flutter Beginners',
        channel: 'Flutter Dev',
        thumbnail: 'https://via.placeholder.com/140x78/2A2D3E/FFFFFF?text=Firebase',
        duration: 2400,
        viewCount: 340000,
        category: 'Education',
        qualities: ['360p', '720p', '1080p'],
        sourceUrl: 'https://example.com/video4',
        videoUrl: 'https://test-streams.mux.dev/x36xfh64.mp4',
      ),
      VideoModel(
        id: 'mock_5',
        title: 'Building a Chat App with Flutter and Firebase',
        channel: 'Mitchell Carl',
        thumbnail: 'https://via.placeholder.com/140x78/2A2D3E/FFFFFF?text=Chat+App',
        duration: 1500,
        viewCount: 120000,
        category: 'Education',
        qualities: ['360p', '720p'],
        sourceUrl: 'https://example.com/video5',
        videoUrl: 'https://test-streams.mux.dev/x36xfh64.mp4',
      ),
      VideoModel(
        id: 'mock_6',
        title: 'Flutter Animation Masterclass',
        channel: 'Flutter Matic',
        thumbnail: 'https://via.placeholder.com/140x78/2A2D3E/FFFFFF?text=Animation',
        duration: 2100,
        viewCount: 78000,
        category: 'Education',
        qualities: ['360p', '720p', '1080p'],
        sourceUrl: 'https://example.com/video6',
        videoUrl: 'https://test-streams.mux.dev/x36xfh64.mp4',
      ),
    ];
  }

  static List<VideoModel> getCategoryVideos(String category) {
    final allVideos = getTrendingVideos();
    if (category == 'Trending') return allVideos;
    return allVideos.where((v) => v.category == category).toList();
  }

  static List<VideoModel> searchVideos(String query) {
    final allVideos = getTrendingVideos();
    final lowerQuery = query.toLowerCase();
    return allVideos
        .where((v) =>
            v.title.toLowerCase().contains(lowerQuery) ||
            v.channel.toLowerCase().contains(lowerQuery))
        .toList();
  }

  static SearchResultModel getTrendingResult({int page = 1, int limit = 20}) {
    final videos = getTrendingVideos();
    final start = (page - 1) * limit;
    final end = (start + limit).clamp(0, videos.length);
    final pageVideos = videos.sublist(start, end);
    return SearchResultModel(
      videos: pageVideos,
      total: videos.length,
      query: '',
      page: page,
      limit: limit,
    );
  }

  static SearchResultModel searchResult(String query, {int page = 1, int limit = 20}) {
    final results = searchVideos(query);
    return SearchResultModel(
      videos: results,
      total: results.length,
      query: query,
      page: page,
      limit: limit,
    );
  }
}
