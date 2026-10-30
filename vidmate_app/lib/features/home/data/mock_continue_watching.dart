// OFFLINE FALLBACK — real backend se replace hota hai, fail par use hota hai
class MockContinueWatching {
  final String title;
  final String channel;
  final String duration;
  final double progress;
  final String thumbnail;

  MockContinueWatching({
    required this.title,
    required this.channel,
    required this.duration,
    required this.progress,
    required this.thumbnail,
  });
}