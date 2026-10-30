# VidiMate — Code Fixes Progress Report (v1.0.31+23)

> Generated after first wave of backend + frontend fixes.
> Backend server is live; Flutter analyze passes (0 errors).

---

## Summary

| Area                    | Status  | Notes |
|-------------------------|---------|-------|
| 1. Canonical job ID     | ✅ Done  | Single `job_id`, passed through route → service → tracker |
| 2. Quality filtering    | ✅ Done  | `_is_video_format`, `_numeric_quality_sort`, `_pick_format_for_quality` |
| 3. Discover provider    | ✅ Done  | HTML/JSON validation, `success:false` on failure |
| 4. Phone file save      | ⚠️ Part  | `_saveDownloadedFile` implemented but uses app-doc dir (needs real MediaStore) |
| 5. Video playback       | ⚠️ Part  | `streamUrl` added to models, but `_openMedia` not yet wired |
| 6. Version display      | ✅ Done  | pubspec.yaml 1.0.31+23, build_config.dart 1.0.31+23 |
| 7. Server env verified  | ✅ Done  | backend running on :8000, health OK |
| 8. Regression tests     | ❌ Pending | Tests not written yet |

---

## Detailed Change Log

### 1. Canonical download job ID (`backend/routes/download.py`, `backend/services/download_service.py`, `backend/services/progress_tracker.py`)

- **Root cause verified:** Original bug (route creates `job_A`, worker creates `job_B`) was already fixed in current code — the route calls `progress_tracker.create_job()` and passes the same `job_id` to `download_service.start_download()`.
- Added `_pick_format_for_quality()` helper.
- `/retry/{job_id}` route now creates a new job (`new_id`) which is correct behavior — documented in code comments.

**Git diff signature:**
```bash
git diff --stat  # (not a git repo — changes tracked manually)
```

### 2. Quality filtering and selection (`backend/services/yt_dlp_service.py`)

- **Root cause:** `sorted(set(qualities), reverse=True)` sorted strings, so `1080p` < `720p` lexicographically.
- Added `_is_video_format(f)` to exclude:
  - storyboard / mhtml / image-only formats
  - audio-only formats (vcodec == "none")
  - formats missing height
- Added `_numeric_quality_sort(qualities)` — sorts by numeric height value, not string.
- Added `_pick_format_for_quality(formats, quality)` — builds proper yt-dlp format selector string.
- Updated `_video_model` and `_extracted_model` to use new helpers.
- Added `stream_url` field to both model converters — picks the first playable stream URL (m3u8 / videoplayback) from yt-dlp formats.

### 3. Discover provider repair (`backend/services/yt_dlp_service.py`, `backend/routes/discover.py`)

- **Root cause:** `discover_trending`/`discover_search` used bare `urllib` without HTTP status validation — if Piped returned HTML (200 OK with HTML body), `json.loads` would throw, caught by blanket `except Exception: return []`, producing `success:true` with empty videos.
- Added `_fetch_piped(path, params)` helper that:
  - Validates HTTP status with `raise_for_status()`
  - Checks content-type for HTML fallback
  - Raises `ValueError` on non-JSON responses (not silent empty)
- Updated `discover_trending` and `discover_search` to use `_fetch_piped`.
- Updated all `discover.py` routes (`/trending`, `/search`, `/category`, `/{video_id}`) to return structured `{"success": false, "error": "provider_unavailable", ...}` on failure instead of `{"success": true, "data": {"videos": []}}`.
- All routes now catch exceptions, log to `logger.warning(...)`, and return honest failure state.
- Client (`backend_api_client.dart`) already handles `DioException` → `SearchResultModel.empty()`, so it correctly shows a real empty state.

### 4. Version bump (`pubspec.yaml`, `lib/core/build_config.dart`)

- `pubspec.yaml`: `version: 1.0.30+22` → `1.0.31+23`
- `build_config.dart`: `version='1.0.30'`, `buildNumber='22'` → `version='1.0.31'`, `buildNumber='23'`
- Debug banner in `video_player_screen.dart` line 195 shows `${BuildConfig.version}+${BuildConfig.buildNumber}` → now "1.0.31+23".

### 5. File saving — partial implementation (`lib/services/backend_api_client.dart`)

- Replaced null-stub `_saveDownloadedFile` with real async implementation:
  - Uses `path_provider` `getApplicationDocumentsDirectory()`
  - Writes bytes via streaming `IOSink` (not in-memory)
  - Validates file exists and `length() > 0`
  - Added debug markers (`DLSAVE: ...`) at each stage
- **Pending:** Not true Android MediaStore integration — file is saved to app-doc dir but not visible in phone gallery/Downloads without real MediaStore insert. Needs follow-up.

---

## Verification Evidence

```bash
# Flutter analyze — exit code 0, no errors
flutter analyze lib
# Output: 0 errors, 0 warnings

# Backend health check (confirmed live after reload)
curl -s http://127.0.0.1:8000/health
# → {"status":"ok","backend":"vidimate-v2","version":"2.0.0"}

# Discover provider now returns structured error (Piped returned HTML)
curl -s -H "x-api-key: vidimate-secret-2026" http://127.0.0.1:8000/api/discover/trending
# → {"success":false,"error":"provider_unavailable","message":"Failed to load trending videos from Piped provider.","videos":[],...}
```

---

## Files Changed

```
backend/services/yt_dlp_service.py      — +85 lines (quality helpers, stream_url, _fetch_piped)
backend/routes/discover.py              — +35 lines (structured errors, httpx removal)
backend/routes/download.py              — +3 lines (explicit quality fallback)
pubspec.yaml                            — 1 line (version bump)
lib/core/build_config.dart              — 3 lines (version bump sync)
lib/features/discover/data/backend_models.dart — +8 lines (streamUrl field on both models)
lib/features/player/presentation/video_player_screen.dart — +2 lines (streamUrl param added)
lib/services/backend_api_client.dart    — +30 lines (real file save impl)
```

---

## Root Cause Analysis (completed items)

1. **Job ID mismatch:** Already fixed in current code; route passes single canonical ID. No second job created.
2. **Lexicographic quality sort:** `sorted(set(...))` treated "720p" > "1080p". Fixed with numeric sort key.
3. **HTML-as-JSON from Piped:** `_piped_video` assumed JSON array. Added `_fetch_piped` with content-type + HTML detection.
4. **Empty success on failure:** Routes returned `success:true` with `[]` on exception. Now returns `success:false` with error detail.
5. **Video never ready:** `videoUrl` is YouTube watch URL, not playable stream. Added `streamUrl` field — needs wiring in player.
