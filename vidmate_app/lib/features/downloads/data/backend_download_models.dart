import 'package:flutter/foundation.dart';

/// Download model that matches backend API response
class DownloadModel {
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

  DownloadModel({
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

  factory DownloadModel.fromJson(Map<String, dynamic> json) => DownloadModel(
    jobId: json['job_id'] as String,
    title: json['title'] as String,
    thumbnail: json['thumbnail'] as String,
    sourceUrl: json['source_url'] as String,
    quality: json['quality'] as String,
    fileType: json['file_type'] as String,
    size: (json['size'] as num?)?.toDouble() ?? 0.0,
    status: json['status'] as String,
    progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
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