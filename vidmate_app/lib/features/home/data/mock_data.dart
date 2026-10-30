// OFFLINE FALLBACK — real backend se replace hota hai, fail par use hota hai
/// Mock data REMOVED - replaced with real backend and local database data
///
/// Home screen now connects to:
/// - POST /api/extract (paste link detection)
/// - POST /api/download (start real download)
/// - Hive database for Continue Watching and Recent Downloads
///
/// Mock data may remain only for:
/// - Automated tests
/// - Offline/error fallback
/// - Development mode behind an explicit setting