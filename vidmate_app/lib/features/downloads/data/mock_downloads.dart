// OFFLINE FALLBACK — real backend se replace hota hai, fail par use hota hai
/// Mock data REMOVED - replaced with real backend data
///
/// Downloads screen now connects to real FastAPI backend endpoints:
/// - POST /api/download
/// - GET /api/status/{job_id}
/// - POST /api/pause/{job_id}
/// - POST /api/resume/{job_id}
/// - POST /api/cancel/{job_id}
/// - POST /api/retry/{job_id}
/// - GET /api/file/{job_id}
///
/// Mock data may remain only for:
/// - Automated tests
/// - Offline/error fallback
/// - Development mode behind an explicit setting