/// Video model for Discover screen
class VideoModel {
  final String id;
  final String title;
  final String channel;
  final String thumbnail;
  final int duration; // in seconds
  final int viewCount;
  final String category;
  final List<String> qualities;
  final String sourceUrl;
  final String videoUrl; // YouTube watch URL (fallback)
  final String streamUrl; // direct playable stream URL (m3u8 / videoplayback)

  VideoModel({
    required this.id,
    required this.title,
    required this.channel,
    required this.thumbnail,
    required this.duration,
    required this.viewCount,
    required this.category,
    required this.qualities,
    required this.sourceUrl,
    required this.videoUrl,
    this.streamUrl = '',
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) => VideoModel(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    channel: json['channel'] as String? ?? '',
    thumbnail: json['thumbnail'] as String? ?? '',
    duration: (json['duration'] as num).toInt(),
    viewCount: (json['view_count'] as num).toInt(),
    category: json['category'] as String? ?? 'video',
    qualities: List<String>.from(json['qualities'] ?? []),
    sourceUrl: json['source_url'] as String? ?? '',
    videoUrl: json['video_url'] as String? ?? '',
    streamUrl: json['stream_url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channel': channel,
    'thumbnail': thumbnail,
    'duration': duration,
    'view_count': viewCount,
    'category': category,
    'qualities': qualities,
    'source_url': sourceUrl,
    'video_url': videoUrl,
    'stream_url': streamUrl,
  };
}

/// Extracted video info from paste link
class ExtractedVideoModel {
  final String id;
  final String title;
  final String thumbnail;
  final int duration;
  final List<String> qualities;
  final String audioOnlyUrl;
  final String videoUrl;
  final String sourceUrl;
  final String streamUrl; // direct playable stream URL (m3u8 / videoplayback)

  ExtractedVideoModel({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.qualities,
    required this.audioOnlyUrl,
    required this.videoUrl,
    required this.sourceUrl,
    this.streamUrl = '',
  });

  factory ExtractedVideoModel.fromJson(Map<String, dynamic> json) => ExtractedVideoModel(
    id: json['id'] as String,
    title: json['title'] as String,
    thumbnail: json['thumbnail'] as String,
    duration: (json['duration'] as num).toInt(),
    qualities: List<String>.from(json['qualities'] ?? []),
    audioOnlyUrl: json['audio_only_url'] as String? ?? '',
    videoUrl: json['video_url'] as String? ?? '',
    sourceUrl: json['source_url'] as String? ?? '',
    streamUrl: json['stream_url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'thumbnail': thumbnail,
    'duration': duration,
    'qualities': qualities,
    'audio_only_url': audioOnlyUrl,
    'video_url': videoUrl,
    'source_url': sourceUrl,
    'stream_url': streamUrl,
  };
}

/// Download job model from backend
class DownloadJobModel {
  final String jobId;
  final String title;
  final String thumbnail;
  final String sourceUrl;
  final String quality;
  final String fileType; // 'video' or 'audio'
  final double size; // in MB
  final String status; // 'pending', 'downloading', 'paused', 'completed', 'failed'
  final double progress; // 0.0 to 1.0
  final double speed; // MB/s
  final String eta;
  final String filePath;
  final Map<String, dynamic> dates;
  final String error;

  DownloadJobModel({
    required this.jobId,
    required this.title,
    required this.thumbnail,
    required this.sourceUrl,
    required this.quality,
    required this.fileType,
    required this.size,
    required this.status,
    required this.progress,
    required this.speed,
    required this.eta,
    required this.filePath,
    required this.dates,
    required this.error,
  });

  factory DownloadJobModel.fromJson(Map<String, dynamic> json) => DownloadJobModel(
    jobId: json['job_id'] as String,
    title: json['title'] as String,
    thumbnail: json['thumbnail'] as String,
    sourceUrl: json['source_url'] as String,
    quality: json['quality'] as String,
    fileType: json['file_type'] as String,
    size: (json['size'] as num).toDouble(),
    status: json['status'] as String,
    progress: (json['progress'] as num).toDouble(),
    speed: (json['speed'] as num).toDouble(),
    eta: json['eta'] as String? ?? '',
    filePath: json['file_path'] as String? ?? '',
    dates: Map<String, dynamic>.from(json['dates'] ?? {}),
    error: json['error'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'title': title,
    'thumbnail': thumbnail,
    'source_url': sourceUrl,
    'quality': quality,
    'file_type': fileType,
    'size': size,
    'status': status,
    'progress': progress,
    'speed': speed,
    'eta': eta,
    'file_path': filePath,
    'dates': dates,
    'error': error,
  };
}

/// Search result model
class SearchResultModel {
  final List<VideoModel> videos;
  final int total;
  final String query;
  final int page;
  final int limit;

  SearchResultModel({
    required this.videos,
    required this.total,
    required this.query,
    required this.page,
    required this.limit,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) => SearchResultModel(
    videos: (json['videos'] as List? ?? []).map((e) => VideoModel.fromJson(e)).toList(),
    total: (json['total'] as num? ?? 0).toInt(),
    query: json['query'] as String? ?? '',
    page: (json['page'] as num? ?? 1).toInt(),
    limit: (json['limit'] as num? ?? 0).toInt(),
  );

  /// Empty result used when the backend is unreachable and no mock data
  /// should be shown (real-data-only mode).
  SearchResultModel.empty()
      : videos = const [],
        total = 0,
        query = '',
        page = 1,
        limit = 0;
}