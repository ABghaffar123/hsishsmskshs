# VidiMate — Pending Work (Not Started)

> These are the items from `VIDIMATE_CRITICAL_FIX_IMPLEMENTATION.md` that are still open.
> None have been started. Listed here for transparency — **no fabrication** of completion.

---

## 1. Wire `streamUrl` into VideoPlayerScreen (`lib/features/player/presentation/video_player_screen.dart`)

### Root Cause
The `VideoPlayerScreen` currently opens `widget.videoUrl` in `_openMedia()`:
```dart
final media = mk.Media(widget.videoUrl);
await _player.open(media);
```
But `videoUrl` is a YouTube **watch URL** (e.g. `https://www.youtube.com/watch?v=...`) — `media_kit` cannot play it directly. It needs a direct stream URL (m3u8 or videoplayback URL).

### Fix Started ✅
- ✅ Added `streamUrl` field to `VideoModel` and `ExtractedVideoModel` in `backend_models.dart`
- ✅ Added `stream_url` to backend `_video_model` and `_extracted_model` in `yt_dlp_service.py`
- ✅ Added `streamUrl` parameter to `VideoPlayerScreen` constructor (default `''`)

### Still Pending ❌
- ❌ `_openMedia()` still uses `widget.videoUrl` — must be changed to `widget.streamUrl` with fallback
- ❌ `discover_screen.dart` navigator push must pass `video.streamUrl`
- ❌ `video_player_from_file_screen.dart` route also needs `streamUrl` if used
- ❌ Verify media_kit can open the m3u8/videoplayback URL (may need headers)

---

## 2. Real Android MediaStore file saving (`lib/services/backend_api_client.dart`)

### Root Cause
`_saveDownloadedFile` currently saves to `getApplicationDocumentsDirectory()` — this is app-private storage and **not visible in phone gallery/Downloads**.

### Fix Started ✅
- ✅ Replaced null stub with async file-writing logic
- ✅ Streaming write (IOSink) to avoid RAM issues
- ✅ File size validation (`> 0` check)
- ✅ Debug markers (`DLSAVE:`)

### Still Pending ❌
- ❌ Use `MediaStore` API for public Downloads/Videos dir visibility
- ❌ Handle content URIs for Android 10+ scoped storage
- ❌ Handle duplicate filenames, Unicode, storage-full errors
- ❌ Publish to MediaStore after save (notify phone gallery)
- ❌ Verify file is actually replayable on phone (separate device test)

---

## 3. Regression test suite (Section 13)

### Still Pending ❌ — All Tests
- ❌ Canonical job identity and worker state updates
- ❌ Quality filtering/selection and output finalization
- ❌ Provider failures, fallback, malformed responses, valid emptiness
- ❌ Actual client/server contract parsing
- ❌ Five-second behavior without artificial cancellation
- ❌ Phone save success/failure and no false completed state
- ❌ Version display sourcing
- ❌ Persistence/reconciliation after restart

---

## 4. Server environment verification (Section 8)

### Still Pending ❌
- ❌ Verify yt-dlp Python library version matches CLI version
- ❌ Test user's exact failing YouTube URL (unknown — not requested)
- ❌ Test Facebook extraction independently (unknown URL — not requested)

---

## 5. Version mismatch repair (Section 10)

### Verified ✅
- `pubspec.yaml`: 1.0.31+23 ✅
- `BuildConfig`: 1.0.31+23 ✅
- Backend `/health`: `vidimate-v2`, `2.0.0` ✅

### Still Pending ❌
- ❌ APK build and inspect version metadata (not built yet)
- ❌ Installed Android native versionName/versionCode (needs `adb shell dumpsys` — not checked)
- ❌ UI version label matches (needs phone deploy)

---

## 6. Release APK build (Section 14)

### Still Pending ❌
- ❌ `flutter build apk --release` (not yet run)
- ❌ Verify release artifact exists with correct version metadata
- ❌ Phone deploy: `flutter run --release -d <device_id>` (not yet run)

---

## 7. Phone file saving — full lifecycle (Section 6)

### Root Cause
Download pipeline: Extract → queue → worker → FFmpeg → completed file → auth transfer → **phone save** → local history/Library update.

### Still Pending ❌
- ❌ Authenticated transfer from backend → phone (`/api/file/{jobId}` endpoint exists but client `_saveDownloadedFile` doesn't verify auth on backend)
- ❌ Backend file endpoint (`/api/file/{job_id}`) does not validate path traversal — security risk
- ❌ Restart recovery (interrupted transfer)
- ❌ Local history/Library persistence after phone save (only Hive save — needs integration)

---

## 8. Backend `/api/file/{job_id}` path traversal guard

### Still Pending ❌
`routes/status.py` `get_file()` does:
```python
path = job.get("file_path", "")
if path and os.path.exists(path):
    return FileResponse(path)
```
- ❌ No path traversal validation (job's `file_path` could be arbitrary)
- ❌ Falls back to `os.walk` scanning downloads dir — inefficient
- ❌ Returns file without MIME type or safe filename header
- ❌ No size/content validation before serving

---

## 9. Pause/Cancel actually stops yt-dlp process

### Still Pending ❌
`routes/download.py` `cancel_download()`:
```python
progress_tracker.set_status(job_id, "cancelled")
return _ok({"message": "cancel requested"})
```
- ❌ No actual process termination — worker continues running
- ❌ yt-dlp subprocess not killed
- ❌ No way to truly pause/resume (only restart)

---

## Priority Order for Next Session

1. Wire `streamUrl` → `_openMedia()` + `discover_screen.dart` (fixes core playback)
2. Phone deploy on device `NEW 15 (wireless)` to verify debug banner shows `1.0.31+23`
3. Real MediaStore file saving
4. Backend file endpoint path traversal guard
5. Release APK build
6. Regression tests

---

## Device Info
- **Connected device:** `NEW 15 (wireless)` — `adb-VNEW1507050301553-CLM0Sf._adb-tls-connect._tcp` — Android 12 (API 31)
- **Backend:** Running on `http://0.0.0.0:8000` (Python 3.12.0)
- **Flutter analyze:** 0 errors ✅
